import jwt from 'jsonwebtoken';

// No hardcoded fallback - a guessable default secret baked into source
// would let anyone who's ever seen this file forge tokens for any user in
// any environment that forgets to set this. Fail loudly at startup instead.
// (A plain `const x = process.env.X; if (!x) throw ...` doesn't narrow to
// `string` in the functions below - TS only narrows within one function.)
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} environment variable is required`);
  return value;
}

const JWT_SECRET = requireEnv('JWT_SECRET');

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d'; // For simple MVP we will issue a 7-day token to avoid complex client refresh mechanisms for now

interface TokenPayload {
  userId: string;
  salonId: string;
  role: string;
}

export function generateToken(payload: TokenPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN as any, algorithm: 'HS256' });
}

export function verifyToken(token: string): TokenPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }) as TokenPayload;
  } catch (error) {
    return null;
  }
}
