<?php
declare(strict_types=1);

/**
 * Разбор calculation из estimates.raw_json (веб-просмотр, PDF).
 * Отдельный файл: на сервере достаточно залить его вместе с admin-web, даже если admin_requests_service.php ещё старый.
 */

if (!function_exists('tp_admin_estimate_calculation_map')) {
    /**
     * @param array<string, mixed> $requestRow строка заявки с полем estimate_raw_json
     * @return array<string, mixed>
     */
    function tp_admin_estimate_calculation_map(array $requestRow): array
    {
        $raw = $requestRow['estimate_raw_json'] ?? null;
        if (!is_string($raw) || $raw === '') {
            return [];
        }
        $j = json_decode($raw, true);
        if (!is_array($j)) {
            return [];
        }
        $c = $j['calculation'] ?? null;
        return is_array($c) ? $c : [];
    }
}
