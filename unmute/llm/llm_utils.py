import os
import re
from copy import deepcopy
from functools import cache
from typing import Any, AsyncIterator, Protocol, cast

from mistralai import Mistral
from openai import AsyncOpenAI, OpenAI

from unmute.kyutai_constants import LLM_SERVER

from ..kyutai_constants import KYUTAI_LLM_API_KEY, KYUTAI_LLM_MODEL

INTERRUPTION_CHAR = "—"  # em-dash
USER_SILENCE_MARKER = "..."


def preprocess_messages_for_llm(
    chat_history: list[dict[str, str]],
) -> list[dict[str, str]]:
    output = []

    for message in chat_history:
        message = deepcopy(message)

        # Sometimes, an interruption happens before the LLM can say anything at all.
        # In that case, we're left with a message with only INTERRUPTION_CHAR.
        # Simplify by removing.
        if message["content"].replace(INTERRUPTION_CHAR, "") == "":
            continue

        if output and message["role"] == output[-1]["role"]:
            output[-1]["content"] += " " + message["content"]
        else:
            output.append(message)

    def role_at(index: int) -> str | None:
        if index >= len(output):
            return None
        return output[index]["role"]

    if role_at(0) == "system" and role_at(1) in [None, "assistant"]:
        # Some LLMs, like Gemma, get confused if the assistant message goes before user
        # messages, so add a dummy user message.
        output = [output[0]] + [{"role": "user", "content": "Hello."}] + output[1:]

    for message in chat_history:
        if (
            message["role"] == "user"
            and message["content"].startswith(USER_SILENCE_MARKER)
            and message["content"] != USER_SILENCE_MARKER
        ):
            # This happens when the user is silent but then starts talking again after
            # the silence marker was inserted but before the LLM could respond.
            # There are special instructions in the system prompt about how to handle
            # the silence marker, so remove the marker from the message to not confuse
            # the LLM
            message["content"] = message["content"][len(USER_SILENCE_MARKER) :]

    return output


async def rechunk_to_words(iterator: AsyncIterator[str]) -> AsyncIterator[str]:
    """Rechunk the stream of text to whole words.

    Otherwise the TTS doesn't know where word boundaries are and will mispronounce
    split words.

    The spaces will be included with the next word, so "foo bar baz" will be split into
    "foo", " bar", " baz".
    Multiple space-like characters will be merged to a single space.
    """
    buffer = ""
    space_re = re.compile(r"\s+")
    prefix = ""
    async for delta in iterator:
        buffer = buffer + delta
        while True:
            match = space_re.search(buffer)
            if match is None:
                break
            chunk = buffer[: match.start()]
            buffer = buffer[match.end() :]
            if chunk != "":
                yield prefix + chunk
            prefix = " "

    if buffer != "":
        yield prefix + buffer


class LLMStream(Protocol):
    async def chat_completion(
        self, messages: list[dict[str, str]]
    ) -> AsyncIterator[str]:
        """Get a chat completion from the LLM."""
        ...


class MistralStream:
    def __init__(self):
        self.current_message_index = 0
        api_key = KYUTAI_LLM_API_KEY or os.environ.get("MISTRAL_API_KEY")
        if not api_key:
            raise ValueError("KYUTAI_LLM_API_KEY or MISTRAL_API_KEY must be set")
        self.mistral = Mistral(api_key=api_key)

    async def chat_completion(
        self, messages: list[dict[str, str]]
    ) -> AsyncIterator[str]:
        model = KYUTAI_LLM_MODEL or "mistral-small-latest"
        event_stream = await self.mistral.chat.stream_async(
            model=model,
            messages=cast(Any, messages),  # It's too annoying to type this properly
            temperature=1.0,
        )

        async for event in event_stream:
            delta = event.data.choices[0].delta.content
            if delta:  # Skip None or empty deltas
                yield delta


def get_openai_client(
    server_url: str = LLM_SERVER, api_key: str | None = KYUTAI_LLM_API_KEY
) -> AsyncOpenAI:
    # AsyncOpenAI() will complain if the API key is not set, so set a dummy string if it's None.
    # This still makes sense when using vLLM because it doesn't care about the API key.
    return AsyncOpenAI(api_key=api_key or "EMPTY", base_url=server_url + "/v1")


@cache
def autoselect_model() -> str:
    if KYUTAI_LLM_MODEL is not None:
        return KYUTAI_LLM_MODEL
    openai_client = get_openai_client()
    # OpenAI() will complain if the API key is not set, so set a dummy string if it's None.
    # This still makes sense when using vLLM because it doesn't care about the API key.
    client_sync = OpenAI(
        api_key=openai_client.api_key or "EMPTY", base_url=openai_client.base_url
    )
    models = client_sync.models.list()
    if len(models.data) != 1:
        raise ValueError("There are multiple models available. Please specify one.")
    return models.data[0].id


class VLLMStream:
    def __init__(
        self,
        client: AsyncOpenAI,
        temperature: float = 1.0,
    ):
        """
        If `model` is None, it will look at the available models, and if there is only
        one model, it will use that one. Otherwise, it will raise.
        """
        self.client = client
        self.model = autoselect_model()
        self.temperature = temperature

    async def chat_completion(
        self, messages: list[dict[str, str]]
    ) -> AsyncIterator[str]:
        stream = await self.client.chat.completions.create(
            model=self.model,
            messages=cast(Any, messages),  # Cast and hope for the best
            stream=True,
            temperature=self.temperature,
        )

        async with stream:
            async for chunk in stream:
                chunk_content = chunk.choices[0].delta.content

                if not chunk_content:
                    # This happens on the first message, see:
                    # https://platform.openai.com/docs/guides/streaming-responses#read-the-responses
                    # Also ignore `null` chunks, which is what llama.cpp does:
                    # https://github.com/ggml-org/llama.cpp/blob/6491d6e4f1caf0ad2221865b4249ae6938a6308c/tools/server/tests/unit/test_chat_completion.py#L338
                    continue

                yield chunk_content
