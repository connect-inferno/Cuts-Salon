import { Request, Response, NextFunction } from 'express';

// Salon onboarding is an internal operation you run yourself for each new
// pilot salon, not a public signup flow - gated by a shared secret rather
// than full admin auth since only you should ever call it.
export function requireOnboardingSecret(req: Request, res: Response, next: NextFunction) {
  const secret = req.headers['x-onboarding-secret'];
  const expected = process.env.ONBOARDING_SECRET;

  if (!expected) {
    return res.status(500).json({ error: 'ONBOARDING_SECRET is not configured on the server' });
  }

  if (secret !== expected) {
    return res.status(401).json({ error: 'Invalid onboarding secret' });
  }

  next();
}
