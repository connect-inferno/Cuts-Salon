import { Router } from 'express';
import { OnboardingController } from '../controllers/onboarding.controller';
import { requireOnboardingSecret } from '../middleware/onboarding.middleware';

const router = Router();

router.post('/salons', requireOnboardingSecret, OnboardingController.onboardSalon);
router.get('/salons', requireOnboardingSecret, OnboardingController.listSalons);

export default router;
