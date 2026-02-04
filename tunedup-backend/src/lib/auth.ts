import { randomBytes, createHmac, randomInt } from 'crypto';
import bcrypt from 'bcryptjs';
import prisma from './prisma';

const SALT_ROUNDS = 12;
const SESSION_EXPIRY_DAYS = parseInt(process.env.SESSION_EXPIRY_DAYS || '30', 10);
const MAGIC_LINK_EXPIRY_MINUTES = parseInt(process.env.MAGIC_LINK_EXPIRY_MINUTES || '15', 10);

// ============================================
// Token Generation
// ============================================

export function generateToken(length: number = 32): string {
  return randomBytes(length).toString('hex');
}

export function generateVerificationCode(): string {
  return String(randomInt(0, 1000000)).padStart(6, '0');
}

function hashVerificationCode(email: string, code: string): string {
  const secret = process.env.MAGIC_LINK_SECRET || '';
  return createHmac('sha256', secret).update(`${email}:${code}`).digest('hex');
}

// ============================================
// Magic Link
// ============================================

export async function createMagicLink(email: string): Promise<string> {
  const code = generateVerificationCode();
  const expiresAt = new Date(Date.now() + MAGIC_LINK_EXPIRY_MINUTES * 60 * 1000);

  const normalizedEmail = email.toLowerCase();
  const token = hashVerificationCode(normalizedEmail, code);

  await prisma.magicLink.create({
    data: {
      email: normalizedEmail,
      token,
      expiresAt,
    },
  });

  return code;
}

export async function verifyMagicLink(
  email: string,
  code: string
): Promise<{ userId: string; email: string } | null> {
  const normalizedEmail = email.toLowerCase();
  const token = hashVerificationCode(normalizedEmail, code);

  const magicLink = await prisma.magicLink.findFirst({
    where: { token, email: normalizedEmail },
  });

  if (!magicLink) return null;
  if (magicLink.usedAt) return null;
  if (magicLink.expiresAt < new Date()) return null;

  // Mark as used
  await prisma.magicLink.update({
    where: { id: magicLink.id },
    data: { usedAt: new Date() },
  });

  // Find or create user
  let user = await prisma.user.findUnique({
    where: { email: magicLink.email },
  });

  if (!user) {
    user = await prisma.user.create({
      data: { email: magicLink.email },
    });
  }

  return { userId: user.id, email: user.email };
}

// ============================================
// Session
// ============================================

export async function createSession(userId: string): Promise<string> {
  const token = generateToken(32);
  const expiresAt = new Date(Date.now() + SESSION_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  await prisma.session.create({
    data: {
      userId,
      token,
      expiresAt,
    },
  });

  return token;
}

export async function validateSession(token: string): Promise<{ userId: string; email: string } | null> {
  const session = await prisma.session.findUnique({
    where: { token },
    include: { user: true },
  });

  if (!session) return null;
  if (session.expiresAt < new Date()) {
    // Clean up expired session
    await prisma.session.delete({ where: { id: session.id } });
    return null;
  }

  return { userId: session.userId, email: session.user.email };
}

export async function invalidateSession(token: string): Promise<void> {
  await prisma.session.delete({ where: { token } }).catch(() => {});
}

// ============================================
// PIN
// ============================================

export async function hashPin(pin: string): Promise<string> {
  return bcrypt.hash(pin, SALT_ROUNDS);
}

export async function verifyPin(pin: string, hash: string): Promise<boolean> {
  return bcrypt.compare(pin, hash);
}

export async function setUserPin(userId: string, pin: string): Promise<void> {
  const hash = await hashPin(pin);
  await prisma.user.update({
    where: { id: userId },
    data: { pinHash: hash },
  });
}

export async function verifyUserPin(userId: string, pin: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { pinHash: true },
  });

  if (!user?.pinHash) return false;
  return verifyPin(pin, user.pinHash);
}

// ============================================
// Request Helpers
// ============================================

export async function getSessionFromRequest(request: Request): Promise<{ userId: string; email: string } | null> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;

  const token = authHeader.slice(7);
  return validateSession(token);
}

export function requireAuth(session: { userId: string; email: string } | null): asserts session is { userId: string; email: string } {
  if (!session) {
    throw new AuthError('Unauthorized');
  }
}

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}
