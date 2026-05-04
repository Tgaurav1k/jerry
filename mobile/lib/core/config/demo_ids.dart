/// Must match `backend/prisma/seed.ts` (DEMO_USER_ID / DEMO_LAWYER_ID).
const kDemoUserId = '11111111-1111-4111-8111-111111111111';
const kDemoLawyerId = '22222222-2222-4222-8222-222222222222';

String demoThreadIdSorted() {
  return kDemoUserId.compareTo(kDemoLawyerId) < 0 ? '$kDemoUserId:$kDemoLawyerId' : '$kDemoLawyerId:$kDemoUserId';
}

bool isDemoAccount(String? userId) =>
    userId == kDemoUserId || userId == kDemoLawyerId;
