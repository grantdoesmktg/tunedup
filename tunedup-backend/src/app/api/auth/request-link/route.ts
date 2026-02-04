import { NextResponse } from 'next/server';
import { Resend } from 'resend';
import { createMagicLink } from '@/lib/auth';
import { validateRequest, requestLinkSchema, ValidationError } from '@/lib/validation';

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'TunedUp <auth@tunedup.dev>';
const APP_URL = process.env.APP_URL || 'http://localhost:3000';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email } = validateRequest(requestLinkSchema, body);

    // Create magic link token
    const token = await createMagicLink(email);

    // Build the magic link URL (deep link for iOS app)
    const magicLinkUrl = `${APP_URL}/auth/verify?token=${encodeURIComponent(token)}`;

    // Send email via Resend
    await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Sign in to TunedUp',
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
          <h1 style="color: #1a1a1a; font-size: 24px; margin-bottom: 24px;">Sign in to TunedUp</h1>
          <p style="color: #4a4a4a; font-size: 16px; line-height: 1.5; margin-bottom: 32px;">
            Click the button below to sign in to your TunedUp account. This link will expire in 15 minutes.
          </p>
          <a href="${magicLinkUrl}" style="display: inline-block; background-color: #2563eb; color: white; font-size: 16px; font-weight: 600; text-decoration: none; padding: 14px 32px; border-radius: 8px;">
            Sign In
          </a>
          <p style="color: #9a9a9a; font-size: 14px; margin-top: 32px;">
            If you didn't request this email, you can safely ignore it.
          </p>
        </div>
      `,
    });

    return NextResponse.json({
      success: true,
      message: 'Check your email for the login link',
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Magic link request error:', error);
    return NextResponse.json({ error: 'Failed to send login link' }, { status: 500 });
  }
}
