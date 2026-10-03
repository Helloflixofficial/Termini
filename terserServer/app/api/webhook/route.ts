import Stripe from "stripe";
import { NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";
import { db } from "@/lib/db";

export async function POST(req: Request) {
    const body = await req.text();
    const signature = req.headers.get('stripe-signature');
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!signature || !webhookSecret) return new NextResponse('Webhook is not configured', { status: 503 });

    let event: Stripe.Event

    try {
        event = getStripe().webhooks.constructEvent(
            body,
            signature,
            webhookSecret,
        )
    } catch (error: any) {
        return new NextResponse('Webhook Error:' + error.message, { status: 400 })
    }
    const session = event.data.object as Stripe.Checkout.Session;
    const userId = session.metadata?.userId;
    const courseId = session.metadata?.courseId;

    if (event.type === 'checkout.session.completed') {
        if (!userId || !courseId) {
            return new NextResponse('Webhook Error: Missing metadata', {
                status: 400,
            })
        }

        if (session.payment_status !== 'paid' && session.payment_status !== 'no_payment_required') {
            return new NextResponse('Payment is not complete', { status: 400 });
        }
        await db.purchase.upsert({
            where: { userId_courseId: { userId, courseId } },
            create: { userId, courseId },
            update: {},
        })
    } else {
        return new NextResponse(
            `Webhook Error: Unhandled event type ${event.type}`,
            {
                status: 200,
            },
        )
    }

    return new NextResponse(null, { status: 200 })

}
