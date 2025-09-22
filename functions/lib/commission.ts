// functions/src/commission.ts
// Cloud Function: On payment document created under a booking, compute backend-only commission split.
// Stores payout records in /payouts/{bookingId}_{paymentId}, hidden from all client reads.

import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';

try {
    admin.initializeApp();
} catch (e) {
    // no-op for local dev hot-reload
}

const COMMISSION_RATE = 0.10; // 10% developer, 90% provider

// Optional: environment secret for a developer account identifier used for payouts ledgering
const DEVELOPER_ACCOUNT_ID = defineSecret('DEVELOPER_ACCOUNT_ID');

export const onPaymentCreated = onDocumentCreated(
    {
        document: 'bookings/{bookingId}/payments/{paymentId}',
        region: 'asia-south1', // Mumbai region close to IST workloads
        secrets: [DEVELOPER_ACCOUNT_ID],
        // Ensure adequate concurrency defaults; adjust if necessary
    },
    async (event) => {
        const { params, data } = event;
        if (!data) return;

        const bookingId = params.bookingId as string;
        const paymentId = params.paymentId as string;
        const payment = data.data() as any;

        // Only process successful payments
        const status = String(payment?.status ?? '');
        if (status !== 'success') return;

        // Idempotency: check if payout already exists
        const payoutId = `${bookingId}_${paymentId}`;
        const payoutsRef = admin.firestore().collection('payouts').doc(payoutId);
        const existing = await payoutsRef.get();
        if (existing.exists) {
            return;
        }

        const amountNum = Number(payment?.amount ?? 0);
        if (!isFinite(amountNum) || amountNum <= 0) {
            console.warn(`Invalid payment amount for ${payoutId}:`, payment?.amount);
            return;
        }

        const amount = Math.round(amountNum * 100) / 100; // 2-decimal safe
        const developerCommissionRaw = amount * COMMISSION_RATE;
        const developerCommission = Math.round(developerCommissionRaw * 100) / 100;
        const providerAmount = Math.round((amount - developerCommission) * 100) / 100;

        // Load booking to get parties
        const bookingRef = admin.firestore().collection('bookings').doc(bookingId);
        const bookingSnap = await bookingRef.get();
        if (!bookingSnap.exists) {
            console.error('Booking not found for payout:', bookingId);
            return;
        }
        const booking = bookingSnap.data() || {};
        const providerId = String(booking.providerId || '');
        const customerId = String(booking.customerId || '');

        // Use secret if provided, else fallback to a static identifier
        const developerAccountId =
            process.env.DEVELOPER_ACCOUNT_ID || 'developer_account';

        // Atomically create hidden payout ledger
        await payoutsRef.set(
            {
                bookingId,
                paymentId,
                providerId,
                customerId,
                amount, // actual paid amount
                currency: payment?.currency || 'INR',
                method: payment?.method || 'unknown',
                commissionRate: COMMISSION_RATE,
                developerCommission,
                providerAmount,
                developerAccountId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                // Optional trace data (not exposed to clients)
                gatewayMeta: payment?.gatewayMeta || null,
            },
            { merge: false }
        );

        // Optionally: mark booking as paid if not already (no commission numbers on booking)
        try {
            if (String(booking.status) !== 'paid') {
                await bookingRef.update({
                    status: 'paid',
                    paymentConfirmed: true,
                    paymentConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    realTimePayment: true,
                });
            }
        } catch (e) {
            console.warn('Booking status update skipped/failed:', e);
        }
    }
);
