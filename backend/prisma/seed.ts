import { PrismaClient, VerificationStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const DEMO_USER_ID = '11111111-1111-4111-8111-111111111111';
const DEMO_LAWYER_ID = '22222222-2222-4222-8222-222222222222';

const SPECIALTIES = [
  'Criminal Law',
  'Civil Law',
  'Family Law',
  'Corporate Law',
  'Tax Law',
  'Property Law',
  'Labour & Employment Law',
  'Intellectual Property Law',
  'Consumer Protection Law',
  'Banking & Finance Law',
  'Environmental Law',
  'Constitutional Law',
  'Immigration Law',
  'Cyber Law',
  'Arbitration & Mediation',
];

async function main() {
  // ─── Specialties ──────────────────────────────────────────────────────────
  for (const name of SPECIALTIES) {
    await prisma.specialty.upsert({
      where: { name },
      update: {},
      create: { name },
    });
  }
  console.log(`Seed: ${SPECIALTIES.length} specialties ready.`);

  // ─── SuperAdmin ───────────────────────────────────────────────────────────
  const saEmail = process.env.SUPER_ADMIN_EMAIL ?? 'superadmin@jerry.dev';
  const saPass = process.env.SUPER_ADMIN_PASSWORD ?? 'SuperAdmin@123';
  const saHash = await bcrypt.hash(saPass, 12);

  await prisma.admin.upsert({
    where: { email: saEmail },
    update: { passwordHash: saHash, isSuperAdmin: true, isActive: true },
    create: {
      email: saEmail,
      passwordHash: saHash,
      fullName: 'Super Admin',
      isSuperAdmin: true,
      isActive: true,
    },
  });
  console.log(`Seed: SuperAdmin ready — ${saEmail}`);

  // ─── Demo users (dev only) ────────────────────────────────────────────────
  if (process.env.NODE_ENV !== 'production') {
    const demoUserPass = process.env.DEMO_USER_PASSWORD ?? 'DemoUser@123';
    const demoLawyerPass = process.env.DEMO_LAWYER_PASSWORD ?? 'DemoLawyer@123';
    const userEmail = process.env.DEMO_USER_EMAIL ?? 'demo.user@jerry.dev';
    const lawyerEmail = process.env.DEMO_LAWYER_EMAIL ?? 'demo.lawyer@jerry.dev';

    const uh = await bcrypt.hash(demoUserPass, 12);
    const lh = await bcrypt.hash(demoLawyerPass, 12);

    await prisma.user.upsert({
      where: { email: userEmail },
      update: { passwordHash: uh, fullName: 'Demo Client' },
      create: {
        id: DEMO_USER_ID,
        email: userEmail,
        passwordHash: uh,
        fullName: 'Demo Client',
        city: 'Mumbai',
        state: 'Maharashtra',
      },
    });

    const demoLawyer = await prisma.lawyer.upsert({
      where: { email: lawyerEmail },
      update: {
        passwordHash: lh,
        fullName: 'Demo Lawyer',
        verificationStatus: VerificationStatus.APPROVED,
        isOnline: true,
      },
      create: {
        id: DEMO_LAWYER_ID,
        email: lawyerEmail,
        passwordHash: lh,
        fullName: 'Demo Lawyer',
        bio: 'Demo advocate for testing.',
        yearsExperience: 7,
        languagesSpoken: ['English', 'Hindi'],
        city: 'Mumbai',
        state: 'Maharashtra',
        verificationStatus: VerificationStatus.APPROVED,
        isOnline: true,
      },
    });

    // Assign first 2 specialties to demo lawyer
    const firstTwo = await prisma.specialty.findMany({ take: 2 });
    for (const s of firstTwo) {
      await prisma.lawyerSpecialty.upsert({
        where: { lawyerId_specialtyId: { lawyerId: demoLawyer.id, specialtyId: s.id } },
        update: {},
        create: { lawyerId: demoLawyer.id, specialtyId: s.id },
      });
    }

    console.log(`Seed: demo user (${userEmail}) + lawyer (${lawyerEmail}) ready.`);
  }
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
