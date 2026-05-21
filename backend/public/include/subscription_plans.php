<?php
declare(strict_types=1);

/**
 * Тарифы PRO (код → цена ₽ за весь период; для отображения «/ мес» считаете на клиенте).
 */
function tp_subscription_plan_catalog(): array
{
    return [
        '1m' => ['title' => 'Подписка на 1 месяц', 'price_rub' => 349.0, 'months' => 1],
        '3m' => ['title' => 'Подписка на 3 месяца', 'price_rub' => 999.0, 'months' => 3],
        '6m' => ['title' => 'Подписка на 6 месяцев', 'price_rub' => 1999.0, 'months' => 6],
        '1y' => ['title' => 'Подписка на 1 год', 'price_rub' => 3999.0, 'months' => 12],
    ];
}

/**
 * @return array{title: string, price_rub: float, months: int}|null
 */
function tp_subscription_plan_by_code(string $code): ?array
{
    $code = strtolower(trim($code));
    $all = tp_subscription_plan_catalog();

    return $all[$code] ?? null;
}
