# Role-Based Notifications Backend (Laravel)

This app now sends role and user context when fetching notifications.
Implement the backend below so buyer/seller/inspector/transporter only receive their own events.

## 1) Migration

Create a notifications table with role targeting:

```php
Schema::create('notifications', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
    $table->string('type', 80);
    $table->string('title');
    $table->text('message');
    $table->json('target_roles')->nullable(); // ["buyer"], ["seller"], ["inspector"], ["transporter"], ["all"]
    $table->string('related_type')->nullable();
    $table->unsignedBigInteger('related_id')->nullable();
    $table->json('data')->nullable();
    $table->boolean('is_read')->default(false);
    $table->timestamp('read_at')->nullable();
    $table->timestamps();
    $table->index(['user_id', 'is_read', 'created_at']);
});
```

## 2) API Routes

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications', [NotificationController::class, 'store']); // internal/admin/event producer
    Route::put('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::put('/notifications/read-all', [NotificationController::class, 'markAllAsRead']);
    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']);
});
```

## 2.1) Notification Model (copy-paste)

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    protected $fillable = [
        'user_id',
        'type',
        'title',
        'message',
        'target_roles',
        'related_type',
        'related_id',
        'data',
        'is_read',
        'read_at',
    ];

    protected $casts = [
        'target_roles' => 'array',
        'data' => 'array',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
    ];
}
```

## 3) Role Filter Logic (Index)

Read query params:
- `role` (sent by app)
- `user_id` (sent by app)

Then return:
- user-specific notifications (`user_id = auth user id`) OR
- role-targeted notifications where `target_roles` contains current role OR `"all"`

For users with role `seller/buyer`, include both `seller` and `buyer` role-targeted records.

### Controller implementation (copy-paste starter)

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $role = strtolower((string) ($request->query('role') ?: $user->role ?: ''));

        $rolesToMatch = [$role];
        if ($role === 'seller/buyer') {
            $rolesToMatch[] = 'seller';
            $rolesToMatch[] = 'buyer';
            $rolesToMatch[] = 'seller/buyer';
        }

        $query = Notification::query()
            ->where(function ($q) use ($user, $rolesToMatch) {
                $q->where('user_id', $user->id)
                  ->orWhereJsonContains('target_roles', 'all');

                foreach ($rolesToMatch as $r) {
                    if (!empty($r)) {
                        $q->orWhereJsonContains('target_roles', $r);
                    }
                }
            })
            ->latest();

        $notifications = $query->limit(100)->get();
        $unreadCount = (clone $query)->where('is_read', false)->count();

        return response()->json([
            'notifications' => $notifications,
            'unread_count' => $unreadCount,
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'message' => ['required', 'string'],
            'type' => ['required', 'string', 'max:80'],
            'target_roles' => ['nullable', 'array'],
            'target_roles.*' => ['string'],
            'related_type' => ['nullable', 'string', 'max:100'],
            'related_id' => ['nullable'],
            'data' => ['nullable', 'array'],
            'user_id' => ['nullable', 'integer'],
        ]);

        $notification = Notification::create([
            'user_id' => $validated['user_id'] ?? null,
            'type' => $validated['type'],
            'title' => $validated['title'],
            'message' => $validated['message'],
            'target_roles' => $validated['target_roles'] ?? null,
            'related_type' => $validated['related_type'] ?? null,
            'related_id' => $validated['related_id'] ?? null,
            'data' => $validated['data'] ?? null,
            'is_read' => false,
        ]);

        return response()->json($notification, 201);
    }

    public function markAsRead(Request $request, int $id)
    {
        $notification = Notification::where('id', $id)
            ->where(function ($q) use ($request) {
                $q->where('user_id', $request->user()->id)->orWhereNull('user_id');
            })
            ->firstOrFail();

        $notification->update([
            'is_read' => true,
            'read_at' => Carbon::now(),
        ]);

        return response()->json(['ok' => true]);
    }

    public function markAllAsRead(Request $request)
    {
        Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => Carbon::now()]);

        return response()->json(['ok' => true]);
    }

    public function destroy(Request $request, int $id)
    {
        $notification = Notification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $notification->delete();
        return response()->json(['ok' => true]);
    }
}
```

### Response shape expected by app

```json
{
  "notifications": [
    {
      "id": 101,
      "type": "bid_received",
      "title": "New bid received",
      "message": "You got a new bid on BMW X5",
      "is_read": false,
      "target_roles": ["seller"],
      "related_type": "vehicle",
      "related_id": 55,
      "data": {"vehicle_id": 55},
      "created_at": "2026-03-20T10:15:00Z"
    }
  ],
  "unread_count": 3
}
```

## 4) Event Producer Examples

Create notifications on domain events:

- Buyer events: `outbid`, `auction_won`, `purchase_confirmed`
- Seller events: `bid_received`, `vehicle_sold`, `payment_received`
- Inspector events: `inspection_assigned`, `inspection_rescheduled`
- Transporter events: `transport_assigned`, `transport_in_transit`, `transport_delivered`

Example:

```php
Notification::create([
    'user_id' => $sellerId,
    'type' => 'bid_received',
    'title' => 'New bid received',
    'message' => 'A new bid has been placed on your listing.',
    'target_roles' => ['seller'],
    'related_type' => 'vehicle',
    'related_id' => $vehicleId,
    'data' => ['vehicle_id' => $vehicleId, 'bid_id' => $bidId],
]);
```

### Recommended helper service

Create `app/Services/NotificationEventService.php`:

```php
<?php

namespace App\Services;

use App\Models\Notification;

class NotificationEventService
{
    public function notifyRole(array $roles, string $type, string $title, string $message, ?string $relatedType = null, $relatedId = null, ?array $data = null): Notification
    {
        return Notification::create([
            'target_roles' => $roles,
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'related_type' => $relatedType,
            'related_id' => $relatedId,
            'data' => $data,
            'is_read' => false,
        ]);
    }

    public function notifyUser(int $userId, string $type, string $title, string $message, ?string $relatedType = null, $relatedId = null, ?array $data = null): Notification
    {
        return Notification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'related_type' => $relatedType,
            'related_id' => $relatedId,
            'data' => $data,
            'is_read' => false,
        ]);
    }
}
```

## 6) Quick test commands

```bash
# Fetch notifications (role-based)
curl -H "Authorization: Bearer <TOKEN>" \
  "https://your-domain.com/api/notifications?role=buyer&user_id=123"

# Create role-targeted notification
curl -X POST -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"type":"transport_assigned","title":"Pickup assigned","message":"New pickup job assigned","target_roles":["transporter"],"data":{"job_id":99}}' \
  "https://your-domain.com/api/notifications"
```

## 5) Real-time Sync (Optional)

If using WebSockets:
- Broadcast created notification event to channel `user.{id}`.
- App already handles polling fallback every 10s, so WS is optional.

