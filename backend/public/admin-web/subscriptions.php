<?php
declare(strict_types=1);

/**
 * Раздел «Подписки PRO»: сводка и ссылки на подписчиков и журнал событий.
 */
require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_subscriptions.php');

$pdo = tp_admin_web_require_login();

$stats = tp_admin_subscriptions_stats($pdo);
$statsWarnings = $stats['warnings'];
unset($stats['warnings']);

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Подписки PRO', 'subscriptions', $adminLogin !== '' ? $adminLogin : null);
?>
<?php foreach ($statsWarnings as $w) { ?>
    <p class="err" style="color:#b45309;border-left:4px solid #f59e0b;padding-left:0.75rem;"><?= tp_admin_web_h($w) ?></p>
<?php } ?>
<p class="meta">Управление подписками приложения: активные тарифы в <code>user_subscriptions</code>, флаг <code>user_profiles.is_pro</code>, события оформления и отмены в <code>subscription_payment_events</code>.</p>

<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(14rem,1fr));gap:1rem;margin-bottom:1.25rem;">
    <div class="card" style="margin-bottom:0;">
        <h2>Активных подписок</h2>
        <p style="font-size:1.75rem;font-weight:700;margin:0.25rem 0 0;"><?= (int) $stats['active_subs'] ?></p>
        <p class="meta" style="margin:0;">Строки со статусом <code>active</code> и сроком в будущем (или без срока).</p>
    </div>
    <div class="card" style="margin-bottom:0;">
        <h2>Пользователей с is_pro</h2>
        <p style="font-size:1.75rem;font-weight:700;margin:0.25rem 0 0;"><?= (int) $stats['is_pro_users'] ?></p>
        <p class="meta" style="margin:0;">Флаг PRO в профиле (синхронизируется с подписками).</p>
    </div>
    <div class="card" style="margin-bottom:0;">
        <h2>Событий за 30 дней</h2>
        <p style="font-size:1.75rem;font-weight:700;margin:0.25rem 0 0;"><?= (int) $stats['events_last_30d'] ?></p>
        <p class="meta" style="margin:0;">Записи в журнале оплат и подписок.</p>
    </div>
</div>

<div class="toolbar">
    <a class="btn" href="admin_subscribers.php">Подписчики</a>
    <a class="btn" href="admin_subscription_events.php">Журнал оплат и подписок</a>
</div>

<p class="meta">Оформление без эквайринга в приложении создаёт событие <code>activated_no_acquiring</code>; отмена — <code>subscription_cancelled</code>.</p>
<?php
tp_admin_web_layout_end();
