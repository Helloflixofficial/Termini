import Stripe from "stripe";
import { getAuthenticatedUserId } from "@/lib/auth";
import { NextResponse } from "next/server";

import { db } from "@/lib/db";
import { getStripe } from "@/lib/stripe";

export async function POST(
  req: Request,
  { params }: { params: { courseId: string } }
) {
  try {
    const userId = await getAuthenticatedUserId(req);
    if (!userId) {
      return new NextResponse("Unauthorized", { status: 401 });
    }
    const stripe = getStripe();

    const course = await db.course.findUnique({
      where: {
        id: params.courseId,
        isPublished: true,
      }
    });

    const purchase = await db.purchase.findUnique({
      where: {
        userId_courseId: {
          userId,
          courseId: params.courseId
        }
      }
    });

    if (purchase) {
      return new NextResponse("Already purchased", { status: 400 });
    }

    if (!course) {
      return new NextResponse("Not found", { status: 404 });
    }
    if (course.price == null || !Number.isFinite(course.price) || course.price <= 0) {
      return NextResponse.json({ error: "This course cannot be purchased right now" }, { status: 409 });
    }

    const line_items: Stripe.Checkout.SessionCreateParams.LineItem[] = [
      {
        quantity: 1,
        price_data: {
          currency: "USD",
          product_data: {
            name: course.title,
            description: course.description!,
          },
          unit_amount: Math.round(course.price! * 100),
        }
      }
    ];

    let stripeCustomer = await db.stripeCustomer.findUnique({
      where: {
        userId,
      },
      select: {
        stripeCustomerId: true,
      }
    });

    if (!stripeCustomer) {
      const customer = await stripe.customers.create({ metadata: { userId } });

      stripeCustomer = await db.stripeCustomer.create({
        data: {
          userId,
          stripeCustomerId: customer.id,
        }
      });
    }

    const appBaseUrl = process.env.APP_BASE_URL || "http://localhost:3000";
    const successUrl = new URL('/checkout/success', appBaseUrl);
    successUrl.searchParams.set('courseId', course.id);
    successUrl.searchParams.set("success", "1");
    const cancelUrl = new URL('/checkout/cancel', appBaseUrl);
    cancelUrl.searchParams.set('courseId', course.id);
    cancelUrl.searchParams.set("canceled", "1");

    const session = await stripe.checkout.sessions.create({
      customer: stripeCustomer.stripeCustomerId,
      line_items,
      mode: 'payment',
      success_url: successUrl.toString(),
      cancel_url: cancelUrl.toString(),
      metadata: {
        courseId: course.id,
        userId,
      }
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    console.log("[COURSE_ID_CHECKOUT]", error);
    return new NextResponse("Internal Error", { status: 500 })
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200 });
}
