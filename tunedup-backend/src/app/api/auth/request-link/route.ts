import { NextResponse } from 'next/server';
import { Resend } from 'resend';
import { createMagicLink } from '@/lib/auth';
import { validateRequest, requestLinkSchema, ValidationError } from '@/lib/validation';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function POST(request: Request) {
  const resend = new Resend(process.env.RESEND_API_KEY);
  const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'TunedUp <auth@tunedup.dev>';
  try {
    const body = await request.json();
    const { email } = validateRequest(requestLinkSchema, body);

    // Create magic link token
    const code = await createMagicLink(email);

    // Send email via Resend
    await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Your TunedUp sign-in code',
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
          <h1 style="color: #1a1a1a; font-size: 24px; margin-bottom: 24px;">Sign in to TunedUp</h1>
          <p style="color: #4a4a4a; font-size: 16px; line-height: 1.5; margin-bottom: 32px;">
            Use the 6-digit code below to sign in. This code will expire in 15 minutes.
          </p>
          <div style="font-size: 28px; letter-spacing: 6px; font-weight: 700; color: #111111; background: #f2f2f2; padding: 12px 16px; border-radius: 10px; display: inline-block;">
            ${code}
          </div>
          <p style="color: #9a9a9a; font-size: 14px; margin-top: 32px;">
            If you didn't request this email, you can safely ignore it.
          </p>
        </div>
      `,
    });

    return NextResponse.json({
      success: true,
      message: 'Check your email for your 6-digit code',
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Magic link request error:', error);
    return NextResponse.json({ error: 'Failed to send login link' }, { status: 500 });
  }
}
