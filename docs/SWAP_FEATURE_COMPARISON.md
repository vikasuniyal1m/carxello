# Swap Feature: Website (swap.php) vs App – Comparison

Website reference: [swap.php?vehicle_id=115](https://carauctionapp.templateforwebsites.com/swap.php?vehicle_id=115) (requires login; redirects to login if not authenticated).

## Summary: **Same feature, fully implemented and working**

The app’s swap flow matches the website’s swap.php flow and uses the same backend logic (Laravel `createSwapOffer` is implemented “according to swap.php”).

---

## 1. Entry point

| Website | App |
|--------|-----|
| Open `swap.php?vehicle_id=115` (after login) | Vehicle Details → expand “Place Bid, Buy Now, Watch & more” → **Swap Options** → opens `SwapPurchaseScreen` with same vehicle |

Same idea: user selects a **target vehicle** (by URL vs by tapping on a listing).

---

## 2. Form fields and behaviour

| Feature | Website (swap.php) | App |
|---------|--------------------|-----|
| Target vehicle | Shown for `vehicle_id` from URL | Shown: year, make, model, price, VIN (`ProductDetailsScreen` → `SwapPurchaseScreen(widget.car)`) |
| Your vehicle VIN | 17-character input | Same: 17-char, validated, `buyer_vehicle_vin` sent to API |
| Your vehicle value | From “Get Valuation” / VIN lookup | Same: **Get vehicle value by VIN** via `CarService.getVehicleValueByVIN()` → `GET /vehicles/value-by-vin` |
| Additional payment | Cash amount | Same: numeric, `additional_payment` in API |
| Payment type | Add Cash / Receive Cash | Same: **Add Cash** → `add`, **Receive Cash** → `resolve` |
| Total offer calculation | swap_vehicle_value ± additional_cash | Same in app: `_totalOfferValue` (add: value + cash; resolve: value − cash, min 0) |
| Balance vs target price | Target price − total offer | Same: `_balance` = `buyNowPrice − _totalOfferValue` |
| Transaction summary | Shown before submit | Same: target, your value, additional payment, balance |
| Submit | Sends data to backend | Same: **Submit Swap Offer** → `POST /swap-offers` with same payload |

Form behaviour and calculations match the website and backend.

---

## 3. Backend API (same for both)

- **Create swap offer:** `POST /api/swap-offers`  
  - Body: `vehicle_id`, `buyer_vehicle_vin` (17), `buyer_vehicle_value`, `additional_payment`, `payment_type` (`add` / `resolve`).  
  - Validation: vehicle exists, user is not seller, vehicle active, auction exists.  
  - Creates a **Bid** with `bid_type = 'swap'`, stores `swap_vin`, `swap_amount`, notifications for seller and buyer.

- **Get vehicle value by VIN:** `GET /api/vehicles/value-by-vin?vin=...`  
  - Used for “your vehicle value” in both flows.

- **My swap offers:** `GET /api/swap-offers/my-offers` and `GET /api/swap-offers/my-offers/{vehicleId}`  
  - Used in app (e.g. Product Details to show “has swap offer”, My Bids).

- **Accept / Reject:** `PUT /api/swap-offers/{bidId}/accept` and `.../reject`  
  - Implemented in `SwapOfferService` and used from Home/My Bids for seller actions.

So the **same feature and the same way of working** (same API and business rules) are used by both website and app.

---

## 4. After submit (confirmation)

| Website | App |
|--------|-----|
| Success / confirmation screen | **SwapOfferConfirmationScreen**: “Offer Submitted”, success icon, message |
| Offer ID | Shown for reference | Now shows **real offer ID** from API (`SWP-{id}`) when available |
| Transaction summary | Shown | Same: target value, your vehicle value, additional payment |
| Next steps | Usually “we’ll verify, inspect, finalize” | Same: Vehicle Verification → Schedule Inspection → Final Approval |
| Back / Home | Navigate away | “Back to Home” pops to Product Details then home |

Confirmation flow is aligned with the website and now uses the real offer ID from the backend when present.

---

## 5. Seller side (accept / reject)

- **Website:** Seller can accept or reject swap offers (e.g. from notifications or a “swap offers” list).
- **App:** Same:
  - `SwapOfferService.acceptOffer(offerId)` and `rejectOffer(offerId)`.
  - Used from **Home** (notifications) and **My Bids** (swap offer cards).
  - Backend: `PUT /swap-offers/{bidId}/accept` and `.../reject`.

So the **same feature and way of working** (same API and flow) are implemented on the seller side too.

---

## 6. Small improvement done in app

- **Confirmation screen:** Previously showed a local display ID. It now shows the **real offer (bid) ID** returned by the API (`swap_offer.id`) as `SWP-{id}` when available, so it matches backend records and support.

---

## Conclusion

- **Same feature:** Swap offer by vehicle (target vehicle + your VIN + value + additional payment + add/resolve cash).  
- **Same way of working:** Same API (`/swap-offers`, `/vehicles/value-by-vin`), same validations, same total-offer and balance logic, same notifications and accept/reject flow.  
- **Fully implemented and working:** Create offer, confirmation with real offer ID, VIN value lookup, seller accept/reject, and my-offers checks are all in place and wired to the same backend used by the website.

The only difference is **entry**: website uses `swap.php?vehicle_id=115`; app uses Vehicle Details → Swap Options for the selected vehicle. Behaviour and backend are the same.
