/**
 * One-off rename: "Demo Lawyer" -> "jerry", "Demo User" -> "gaurav".
 *
 * Usage from backend/:
 *   npx ts-node --transpile-only scripts/rename-demo-accounts.ts
 */
import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  try {
    const lawyer = await prisma.lawyer.updateMany({
      where: { email: 'demo.lawyer@jerry.dev' },
      data:  { fullName: 'jerry' },
    });
    const user = await prisma.user.updateMany({
      where: { email: 'demo.user@jerry.dev' },
      data:  { fullName: 'gaurav' },
    });
    console.log(`Lawyer rows updated: ${lawyer.count}`);
    console.log(`User rows updated:   ${user.count}`);

    const verifyLawyer = await prisma.lawyer.findUnique({
      where: { email: 'demo.lawyer@jerry.dev' },
      select: { email: true, fullName: true },
    });
    const verifyUser = await prisma.user.findUnique({
      where: { email: 'demo.user@jerry.dev' },
      select: { email: true, fullName: true },
    });
    console.log('Lawyer now:', verifyLawyer);
    console.log('User now:  ', verifyUser);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
