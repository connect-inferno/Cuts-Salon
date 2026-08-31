import prisma from '../utils/prisma';
import { comparePassword } from '../utils/hash';
import { generateToken } from '../utils/jwt';

export class AuthService {
  static async login(email: string, password: string) {
    const user = await prisma.user.findUnique({
      where: { email },
      include: {
        employeeProfile: true,
        salon: true,
      },
    });

    if (!user) {
      throw new Error('Invalid email or password');
    }

    if (!user.salon.active) {
      throw new Error('This salon account is inactive');
    }

    const isPasswordValid = await comparePassword(password, user.passwordHash);
    if (!isPasswordValid) {
      throw new Error('Invalid email or password');
    }

    const token = generateToken({
      userId: user.id,
      salonId: user.salonId,
      role: user.role,
    });

    return {
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        profile: user.employeeProfile ? {
          id: user.employeeProfile.id,
          name: user.employeeProfile.name,
          phone: user.employeeProfile.phone,
          roleTitle: user.employeeProfile.roleTitle,
          active: user.employeeProfile.active,
        } : null,
      },
      salon: {
        id: user.salon.id,
        name: user.salon.name,
        slug: user.salon.slug,
      },
    };
  }

  static async getMe(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        employeeProfile: true,
        salon: true,
      },
    });

    if (!user) {
      throw new Error('User not found');
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      profile: user.employeeProfile ? {
        id: user.employeeProfile.id,
        name: user.employeeProfile.name,
        phone: user.employeeProfile.phone,
        roleTitle: user.employeeProfile.roleTitle,
        active: user.employeeProfile.active,
      } : null,
      salon: {
        id: user.salon.id,
        name: user.salon.name,
        slug: user.salon.slug,
      },
    };
  }
}
