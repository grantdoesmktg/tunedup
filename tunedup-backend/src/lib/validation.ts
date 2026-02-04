import { z } from 'zod';

// ============================================
// Request Validation Schemas
// ============================================

export const emailSchema = z.string().email('Invalid email format').toLowerCase();

export const pinSchema = z
  .string()
  .length(4, 'PIN must be exactly 4 digits')
  .regex(/^\d{4}$/, 'PIN must contain only digits');

export const requestLinkSchema = z.object({
  email: emailSchema,
});

export const verifySchema = z.object({
  token: z.string().min(1, 'Token is required'),
});

export const pinSetSchema = z.object({
  pin: pinSchema,
});

export const pinVerifySchema = z.object({
  pin: pinSchema,
});

// Vehicle input
export const vehicleInputSchema = z.object({
  year: z.number().int().min(1900).max(2030),
  make: z.string().min(1).max(50),
  model: z.string().min(1).max(50),
  trim: z.string().min(1).max(100),
  engine: z.string().max(100).optional(),
  drivetrain: z.string().max(20).optional(),
  fuel: z.string().max(20).optional(),
  transmission: z.enum(['manual', 'auto', 'unknown']),
});

// Intent input
export const intentInputSchema = z.object({
  budget: z.number().positive().max(500000),
  goals: z.object({
    power: z.number().int().min(1).max(5),
    handling: z.number().int().min(1).max(5),
    reliability: z.number().int().min(1).max(5),
  }),
  dailyDriver: z.boolean(),
  emissionsSensitive: z.boolean(),
  existingMods: z.string().max(1000),
  elevation: z.string().max(100).optional(),
  climate: z.string().max(100).optional(),
  tireType: z.string().max(50).optional(),
  weight: z.number().positive().max(10000).optional(),
  city: z.string().max(100).optional(),
});

export const createBuildSchema = z.object({
  vehicle: vehicleInputSchema,
  intent: intentInputSchema,
});

// Chat
export const chatSchema = z.object({
  buildId: z.string().cuid(),
  message: z.string().min(1).max(500, 'Message must be under 500 characters'),
});

// ============================================
// Validation Helper
// ============================================

export function validateRequest<T>(schema: z.ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    const errors = result.error.errors.map((e) => e.message).join(', ');
    throw new ValidationError(errors);
  }
  return result.data;
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}
