import Stripe from "stripe";

let stripeClient: Stripe | undefined;

export function getStripe() {
  const secretKey = process.env.STRIPE_API_KEY;
  if (!secretKey) throw new Error("STRIPE_API_KEY is not configured");
  stripeClient ??= new Stripe(secretKey, { apiVersion: "2023-08-16", typescript: true });
  return stripeClient;
}
