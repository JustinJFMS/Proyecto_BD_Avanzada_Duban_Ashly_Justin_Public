USE e_commerce;

DROP DATABASE e_commerce;

-- 8 EVENTOS
SET GLOBAL event_scheduler = ON;


CREATE TABLE IF NOT EXISTS promociones (
    id_promocion INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NULL,
    nombre VARCHAR(150),
    descripcion TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    descuento DECIMAL(5,2) DEFAULT 0,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_promociones_producto
      FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);


ALTER TABLE promociones ADD COLUMN fecha_fin DATE;
ALTER TABLE promociones ADD COLUMN activa TINYINT(1) NOT NULL DEFAULT 1;


-- ===========================================
-- TABLA: clientes → columnas usadas en eventos
-- ===========================================
ALTER TABLE clientes 
ADD COLUMN activo BOOLEAN DEFAULT TRUE,
ADD COLUMN nivel_lealtad VARCHAR(20) DEFAULT 'Bronce',
ADD COLUMN intentos_fallidos INT DEFAULT 0,
ADD COLUMN fecha_nacimiento DATE NULL;

ALTER TABLE clientes
ADD COLUMN total_gastado DECIMAL(12,2) NOT NULL DEFAULT 0;

-- ===========================================
-- TABLA: categorias → por conteo de productos
-- ===========================================
ALTER TABLE categorias 
ADD COLUMN cantidad_productos INT DEFAULT 0;

-- ===========================================
-- TABLA: kpis_mensuales → usada en KPIs
-- ===========================================
CREATE TABLE IF NOT EXISTS kpis_mensuales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mes VARCHAR(10),
    total_ventas DECIMAL(12,2)
);

-- ===========================================
-- TABLA: resumen_ventas_diarias → usada en reportes
-- ===========================================
CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE,
    total_dia DECIMAL(12,2)
);

-- =============================================================
-- 1️ evt_generate_weekly_sales_report
-- =============================================================
DROP EVENT IF EXISTS evt_generate_weekly_sales_report;
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
DO
INSERT INTO resumen_ventas_diarias (fecha, total_dia)
SELECT CURDATE(), SUM(total) FROM ventas
WHERE WEEK(fecha_venta) = WEEK(CURDATE()) AND YEAR(fecha_venta) = YEAR(CURDATE());

-- PRUEBA
SELECT * FROM resumen_ventas_diarias ORDER BY fecha DESC LIMIT 1;


-- =============================================================
-- 2️ evt_cleanup_temp_tables_daily
-- =============================================================
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily;
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
DO
DROP TABLE IF EXISTS tmp_productos, tmp_clientes, tmp_ventas;

-- PRUEBA
SHOW TABLES LIKE 'tmp%';


-- =============================================================
-- 3️ evt_archive_old_logs_monthly
-- =============================================================
DROP EVENT IF EXISTS evt_archive_old_logs_monthly;
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
DO
INSERT INTO ventas_archivo SELECT * FROM ventas WHERE fecha_venta < DATE_SUB(CURDATE(), INTERVAL 6 MONTH);

-- PRUEBA
SELECT COUNT(*) AS registros_archivados FROM ventas_archivo;


-- =============================================================
-- 4️ evt_deactivate_expired_promotions_hourly
-- =============================================================
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly;
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
DO
UPDATE promociones SET activa = FALSE WHERE fecha_fin < NOW();

-- PRUEBA
SELECT * FROM promociones WHERE activa = FALSE;


-- =============================================================
-- 5️ evt_recalculate_customer_loyalty_tiers_nightly
-- =============================================================
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly;
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
DO
UPDATE clientes
SET nivel_lealtad = CASE
    WHEN total_gastado >= 1000000 THEN 'Oro'
    WHEN total_gastado >= 500000 THEN 'Plata'
    ELSE 'Bronce'
END;

-- PRUEBA
SELECT nombre, total_gastado, nivel_lealtad FROM clientes LIMIT 5;


-- =============================================================
-- 6️ evt_generate_reorder_list_daily
-- =============================================================
DROP EVENT IF EXISTS evt_generate_reorder_list_daily;
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO alertas_stock (id_producto, stock_actual)
SELECT id_producto, stock FROM productos WHERE stock < 5;

-- PRUEBA
SELECT * FROM alertas_stock ORDER BY fecha_alerta DESC LIMIT 3;


-- =============================================================
-- 7️ evt_rebuild_indexes_weekly
-- =============================================================
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly;
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
DO
OPTIMIZE TABLE productos, ventas, clientes, detalle_ventas;

-- PRUEBA
SHOW TABLE STATUS LIKE 'productos';


-- =============================================================
-- 8️ evt_suspend_inactive_accounts_quarterly
-- =============================================================
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly;
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
DO
UPDATE clientes SET activo = FALSE
WHERE ultima_compra < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

-- PRUEBA
SELECT id_cliente, activo, ultima_compra FROM clientes LIMIT 5;


-- =============================================================
-- 9️ evt_aggregate_daily_sales_data
-- =============================================================
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data;
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO resumen_ventas_diarias (fecha, total_dia)
SELECT CURDATE(), SUM(total) FROM ventas WHERE DATE(fecha_venta) = CURDATE();

-- PRUEBA
SELECT * FROM resumen_ventas_diarias ORDER BY fecha DESC LIMIT 3;


-- =============================================================
-- 10 evt_check_data_consistency_nightly
-- =============================================================
DROP EVENT IF EXISTS evt_check_data_consistency_nightly;
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO auditoria_permisos (usuario, accion)
SELECT 'system', CONCAT('Verificación diaria de consistencia: ', COUNT(*))
FROM ventas WHERE id_venta NOT IN (SELECT DISTINCT id_venta FROM detalle_ventas);

-- PRUEBA
SELECT * FROM auditoria_permisos ORDER BY fecha DESC LIMIT 3;


-- =============================================================
-- 1️1 evt_send_birthday_greetings_daily
-- =============================================================
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily;
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO auditoria_clientes (id_cliente, nombre_completo, email)
SELECT id_cliente, CONCAT(nombre, ' ', apellido), email
FROM clientes WHERE DATE_FORMAT(fecha_nacimiento, '%m-%d') = DATE_FORMAT(CURDATE(), '%m-%d');

-- PRUEBA
SELECT * FROM auditoria_clientes ORDER BY fecha_registro DESC LIMIT 3;


-- =============================================================
-- 1️2 evt_auto_backup_sales_monthly
-- =============================================================
DROP EVENT IF EXISTS evt_auto_backup_sales_monthly;
CREATE EVENT evt_auto_backup_sales_monthly
ON SCHEDULE EVERY 1 MONTH
DO
INSERT INTO ventas_archivo SELECT * FROM ventas WHERE MONTH(fecha_venta) = MONTH(CURDATE() - INTERVAL 1 MONTH);

-- PRUEBA
SELECT COUNT(*) AS backup_registros FROM ventas_archivo;


-- =============================================================
-- 1️3 evt_clear_audit_logs_yearly
-- =============================================================
DROP EVENT IF EXISTS evt_clear_audit_logs_yearly;
CREATE EVENT evt_clear_audit_logs_yearly
ON SCHEDULE EVERY 1 YEAR
DO
DELETE FROM auditoria_precios WHERE fecha_cambio < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

-- PRUEBA
SELECT COUNT(*) FROM auditoria_precios;


-- =============================================================
-- 1️4 evt_refresh_monthly_kpis
-- =============================================================
DROP EVENT IF EXISTS evt_refresh_monthly_kpis;
CREATE EVENT evt_refresh_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
DO
INSERT INTO kpis_mensuales (mes, total_ventas)
SELECT DATE_FORMAT(CURDATE(), '%Y-%m'), SUM(total)
FROM ventas WHERE MONTH(fecha_venta) = MONTH(CURDATE());

-- PRUEBA
SELECT * FROM kpis_mensuales ORDER BY id DESC LIMIT 1;


-- =============================================================
-- 1️5 evt_expire_inactive_promotions_daily
-- =============================================================
DROP EVENT IF EXISTS evt_expire_inactive_promotions_daily;
CREATE EVENT evt_expire_inactive_promotions_daily
ON SCHEDULE EVERY 1 DAY
DO
UPDATE promociones SET activa = FALSE WHERE fecha_fin < CURDATE();

-- PRUEBA
SELECT * FROM promociones WHERE activa = FALSE;


-- =============================================================
-- 1️6 evt_reset_failed_logins_weekly
-- =============================================================
DROP EVENT IF EXISTS evt_reset_failed_logins_weekly;
CREATE EVENT evt_reset_failed_logins_weekly
ON SCHEDULE EVERY 1 WEEK
DO
UPDATE clientes SET intentos_fallidos = 0;

-- PRUEBA
SELECT id_cliente, intentos_fallidos FROM clientes LIMIT 5;


-- =============================================================
-- 1️7 evt_log_system_heartbeat_hourly
-- =============================================================
DROP EVENT IF EXISTS evt_log_system_heartbeat_hourly;
CREATE EVENT evt_log_system_heartbeat_hourly
ON SCHEDULE EVERY 1 HOUR
DO
INSERT INTO auditoria_permisos (usuario, accion)
VALUES ('system', CONCAT('Heartbeat registrado a las ', NOW()));

-- PRUEBA
SELECT * FROM auditoria_permisos ORDER BY fecha DESC LIMIT 1;


-- =============================================================
-- 1️8 evt_archive_inactive_clients_yearly
-- =============================================================
DROP EVENT IF EXISTS evt_archive_inactive_clients_yearly;
CREATE EVENT evt_archive_inactive_clients_yearly
ON SCHEDULE EVERY 1 YEAR
DO
INSERT INTO auditoria_clientes (id_cliente, nombre_completo, email)
SELECT id_cliente, CONCAT(nombre, ' ', apellido), email
FROM clientes WHERE activo = FALSE;

-- PRUEBA
SELECT COUNT(*) FROM auditoria_clientes;


-- =============================================================
-- 1️9 evt_auto_delete_old_alerts_monthly
-- =============================================================
DROP EVENT IF EXISTS evt_auto_delete_old_alerts_monthly;
CREATE EVENT evt_auto_delete_old_alerts_monthly
ON SCHEDULE EVERY 1 MONTH
DO
DELETE FROM alertas_stock WHERE fecha_alerta < DATE_SUB(CURDATE(), INTERVAL 3 MONTH);

-- PRUEBA
SELECT COUNT(*) AS alertas_activas FROM alertas_stock;


-- =============================================================
-- 2️0 evt_refresh_category_counts_weekly
-- =============================================================
DROP EVENT IF EXISTS evt_refresh_category_counts_weekly;
CREATE EVENT evt_refresh_category_counts_weekly
ON SCHEDULE EVERY 1 WEEK
DO
UPDATE categorias c
SET cantidad_productos = (
    SELECT COUNT(*) FROM productos p WHERE p.id_categoria = c.id_categoria
);

-- PRUEBA
SELECT id_categoria, cantidad_productos FROM categorias LIMIT 5;
