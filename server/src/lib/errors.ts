export class ApiError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static badRequest(code: string, message: string) { return new ApiError(400, code, message); }
  static unauthorized(code: string, message: string) { return new ApiError(401, code, message); }
  static forbidden(code: string, message: string) { return new ApiError(403, code, message); }
  static notFound(code: string, message: string) { return new ApiError(404, code, message); }
  static tooMany(code: string, message: string) { return new ApiError(429, code, message); }
}
