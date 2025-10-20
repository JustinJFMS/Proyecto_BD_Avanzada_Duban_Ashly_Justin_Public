USE e_commerce;

DROP DATABASE e_commerce;


-- 7 triggers
-- Tablas auxiliares/columnas que ciertos triggers necesitan
CREATE TABLE IF NOT EXISTS auditoria_precios (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    nombre_producto VARCHAR(150),
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario_responsable VARCHAR(100),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS auditoria_clientes (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre_completo VARCHAR(200),
    email VARCHAR(120),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auditoria_estados_pedidos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alertas_stock (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    stock_actual INT,
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ventas_archivo LIKE ventas;

CREATE TABLE IF NOT EXISTS auditoria_permisos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100),
    accion VARCHAR(255),
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categorias (nombre, descripcion)
SELECT 'General', 'Categoría por defecto'
WHERE NOT EXISTS (SELECT 1 FROM categorias WHERE nombre='General');
-- =============================================================
-- 1️ trg_audit_precio_producto_after_update
-- =============================================================
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO auditoria_precios (id_producto, nombre_producto, precio_anterior, precio_nuevo, usuario_responsable)
        VALUES (NEW.id_producto, NEW.nombre, OLD.precio, NEW.precio, CURRENT_USER());
    END IF;
END;

-- PRUEBA
UPDATE productos SET precio = precio + 10 WHERE id_producto = 1;
SELECT * FROM auditoria_precios ORDER BY fecha_cambio DESC LIMIT 1;


-- =============================================================
-- 2️ trg_check_stock_before_insert_venta
-- =============================================================
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE stock_actual INT;
    SELECT stock INTO stock_actual FROM productos WHERE id_producto = NEW.id_producto;
    IF stock_actual < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay suficiente stock disponible para este producto.';
    END IF;
END;

-- PRUEBA (debe fallar si stock < cantidad)
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
VALUES (1, 1, 9999, 100000);


-- =============================================================
-- 3️ trg_update_stock_after_insert_venta
-- =============================================================
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos SET stock = stock - NEW.cantidad WHERE id_producto = NEW.id_producto;
END;

-- PRUEBA

ALTER TABLE ventas 
MODIFY id_sucursal INT NOT NULL DEFAULT 1;
INSERT INTO ventas (id_cliente, estado, total, fecha_venta)
VALUES (1,'Procesando',0,NOW());


INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
VALUES (LAST_INSERT_ID(), 2, 1, 250000);


SELECT id_producto, stock FROM productos WHERE id_producto = 2;

-- =============================================================
-- 4️ trg_prevent_delete_categoria_with_products
-- =============================================================
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE cant INT;
    SELECT COUNT(*) INTO cant FROM productos WHERE id_categoria = OLD.id_categoria;
    IF cant > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar una categoría con productos asociados.';
    END IF;
END;

-- PRUEBA
DELETE FROM categorias WHERE id_categoria = 1;  -- debe fallar


-- =============================================================
-- 5️ trg_log_new_customer_after_insert
-- =============================================================
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_clientes (id_cliente, nombre_completo, email)
    VALUES (NEW.id_cliente, CONCAT(NEW.nombre, ' ', NEW.apellido), NEW.email);
END;

-- PRUEBA
INSERT INTO clientes (nombre, apellido, email, contraseña)
VALUES ('Laura', 'Nieves', 'lauran@example.com', 'Pass@2025');
SELECT * FROM auditoria_clientes WHERE email = 'lauran@example.com';


-- =============================================================
-- 6️ trg_update_total_gastado_cliente
-- =============================================================
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente;
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET total_gastado = COALESCE(total_gastado, 0) + NEW.total,
        ultima_compra = NEW.fecha_venta
    WHERE id_cliente = NEW.id_cliente;
END;

-- PRUEBA
INSERT INTO ventas (id_cliente, estado, total, fecha_venta)
VALUES (1, 'Entregado', 300000, NOW());
SELECT id_cliente, total_gastado FROM clientes WHERE id_cliente = 1;


-- =============================================================
-- 7️ trg_set_fecha_modificacion_producto
-- =============================================================
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto;
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END;

-- PRUEBA
UPDATE productos SET descripcion = 'Actualizado con trigger' WHERE id_producto = 3;
SELECT id_producto, fecha_modificacion FROM productos WHERE id_producto = 3;


-- =============================================================
-- 8️ trg_prevent_negative_stock
-- =============================================================
DROP TRIGGER IF EXISTS trg_prevent_negative_stock;
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El stock no puede ser negativo.';
    END IF;
END;

-- PRUEBA
UPDATE productos SET stock = -5 WHERE id_producto = 4;  -- debe lanzar error


-- =============================================================
-- 9️ trg_capitalize_nombre_cliente
-- =============================================================
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UCASE(LEFT(NEW.nombre,1)), LCASE(SUBSTRING(NEW.nombre,2)));
    SET NEW.apellido = CONCAT(UCASE(LEFT(NEW.apellido,1)), LCASE(SUBSTRING(NEW.apellido,2)));
END;

-- PRUEBA
SELECT nombre, apellido FROM clientes WHERE email = 'sofiagomez@example.com';


-- =============================================================
-- 10 trg_recalculate_total_venta_on_detalle_change
-- =============================================================
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change;
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = (
        SELECT SUM(precio_unitario_congelado * cantidad)
        FROM detalle_ventas WHERE id_venta = NEW.id_venta
    )
    WHERE id_venta = NEW.id_venta;
END;

-- PRUEBA
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
VALUES (1, 5, 1, 200000);
SELECT total FROM ventas WHERE id_venta = 1;


-- =============================================================
-- 1️1 trg_log_order_status_change
-- =============================================================
DROP TRIGGER IF EXISTS trg_log_order_status_change;
CREATE TRIGGER trg_log_order_status_change
BEFORE UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO auditoria_estados_pedidos (id_venta, estado_anterior, estado_nuevo)
        VALUES (OLD.id_venta, OLD.estado, NEW.estado);
    END IF;
END;

-- PRUEBA
UPDATE ventas SET estado = 'Enviado' WHERE id_venta = 2;
SELECT * FROM auditoria_estados_pedidos ORDER BY fecha_cambio DESC LIMIT 1;


-- =============================================================
-- 1️2 trg_prevent_price_zero_or_less
-- =============================================================
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less;
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio no puede ser menor o igual a 0.';
    END IF;
END;

-- PRUEBA
UPDATE productos SET precio = 0 WHERE id_producto = 5;  -- debe lanzar error


-- =============================================================
-- 1️3 trg_send_stock_alert_on_low_stock
-- =============================================================
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 5 THEN
        INSERT INTO alertas_stock (id_producto, stock_actual)
        VALUES (NEW.id_producto, NEW.stock);
    END IF;
END;

-- PRUEBA
UPDATE productos SET stock = 3 WHERE id_producto = 6;
SELECT * FROM alertas_stock ORDER BY fecha_alerta DESC LIMIT 1;


-- =============================================================
-- 1️4 trg_archive_deleted_venta
-- =============================================================
DROP TRIGGER IF EXISTS trg_archive_deleted_venta;
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivo SELECT * FROM ventas WHERE id_venta = OLD.id_venta;
END;

-- PRUEBA
INSERT INTO ventas (id_cliente, estado, total, fecha_venta)
VALUES (1, 'Procesando', 200000, NOW());
SET @idv := LAST_INSERT_ID();
DELETE FROM ventas WHERE id_venta = @idv;
SELECT * FROM ventas_archivo WHERE id_venta = @idv;


-- =============================================================
-- 1️5 trg_validate_email_format_on_customer
-- =============================================================
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer;
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El formato del correo electrónico no es válido.';
    END IF;
END;

-- PRUEBA
INSERT INTO clientes (nombre, apellido, email, contraseña)
VALUES ('Ana','Lopez','correo_invalido','Pass@2025');  -- debe lanzar error


-- =============================================================
-- 1️6 trg_update_last_order_date_customer
-- =============================================================
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes SET ultima_compra = NEW.fecha_venta WHERE id_cliente = NEW.id_cliente;
END;

-- PRUEBA
INSERT INTO ventas (id_cliente, estado, total, fecha_venta)
VALUES (2, 'Entregado', 120000, NOW());
SELECT id_cliente, ultima_compra FROM clientes WHERE id_cliente = 2;


-- =============================================================
-- 1️7 trg_prevent_self_referral
-- =============================================================
DROP TRIGGER IF EXISTS trg_prevent_self_referral;
CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido_por = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede referirse a sí mismo.';
    END IF;
END;

-- PRUEBA
INSERT INTO clientes (nombre, apellido, email, contraseña, id_referido_por)
VALUES ('Mario','Perez','mao@example.com','Clave@2025', LAST_INSERT_ID());  


-- =============================================================
-- 1️8 trg_log_permission_changes
-- =============================================================
DROP TRIGGER IF EXISTS trg_log_permission_changes;
CREATE TRIGGER trg_log_permission_changes
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_permisos (usuario, accion)
    VALUES (CURRENT_USER(), CONCAT('Cambio en cliente ID ', NEW.id_cliente));
END;

-- PRUEBA
UPDATE clientes SET nombre = 'Carlos' WHERE id_cliente = 3;
SELECT * FROM auditoria_permisos ORDER BY fecha DESC LIMIT 1;


-- =============================================================
-- 1️9 trg_assign_default_category_on_null
-- =============================================================
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null;
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = (SELECT id_categoria FROM categorias WHERE nombre = 'General' LIMIT 1);
    END IF;
END;

-- PRUEBA
SELECT nombre, id_categoria FROM productos WHERE nombre = 'Producto Genérico';


-- =============================================================
-- 20 trg_update_producto_count_in_categoria
-- =============================================================
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria;
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET cantidad_productos = (SELECT COUNT(*) FROM productos WHERE id_categoria = NEW.id_categoria)
    WHERE id_categoria = NEW.id_categoria;
END;

-- PRUEBA
SELECT id_categoria, cantidad_productos FROM categorias WHERE id_categoria = 2;

