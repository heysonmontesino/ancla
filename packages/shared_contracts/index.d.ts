export declare const AI_CHAT_MAX_MESSAGE_LENGTH: 2000;

export type AiChatRequestBody = {
  message: string;
};

export type ApiErrorInfo = {
  message: string;
  statusCode?: number;
};

export declare function createAiChatRequest(
  message: string,
): AiChatRequestBody;
