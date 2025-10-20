USE e_commerce;

DROP DATABASE e_commerce;

-- 9. Procedimientos Almacenados

-- ======================================================
-- 1. sp_RealizarNuevaVenta
-- Descripción: Procesa una nueva venta desde un JSON de productos.
-- Parámetros: p_id_cliente, p_productos (JSON [{id_producto,cantidad}]), p_direccion_envio (opcional).
-- Comportamiento: Verifica stock, calcula total, inserta venta y detalle, actualiza stock y dirección.
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_productos JSON,
    IN p_direccion_envio TEXT
)
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0;
    DECLARE v_id_venta INT;
    DECLARE i INT DEFAULT 0;
    DECLARE v_producto_count INT;
    DECLARE v_producto_id INT;
    DECLARE v_cantidad INT;
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_stock_actual INT;
    DECLARE v_mensaje_error VARCHAR(255);

    -- Manejo de errores: deshacer y relanzar
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Contar productos en el JSON
    SET v_producto_count = JSON_LENGTH(p_productos);

    -- Validar stock y calcular total
    WHILE i < v_producto_count DO
        SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_productos, CONCAT('$[', i, '].id_producto')));
        SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_productos, CONCAT('$[', i, '].cantidad')));

        SELECT precio, stock INTO v_precio, v_stock_actual
        FROM productos 
        WHERE id_producto = v_producto_id AND activo = TRUE;

        IF v_stock_actual IS NULL THEN
            SET v_mensaje_error = CONCAT('Producto inexistente o inactivo ID: ', v_producto_id);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje_error;
        END IF;

        IF v_stock_actual < v_cantidad THEN
            SET v_mensaje_error = CONCAT('Stock insuficiente para producto ID: ', v_producto_id);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje_error;
        END IF;

        SET v_total = v_total + (v_precio * v_cantidad);
        SET i = i + 1;
    END WHILE;

    -- Insertar venta (estado inicial: Pendiente de Pago)
    INSERT INTO ventas (id_cliente, estado, total)
    VALUES (p_id_cliente, 'Pendiente de Pago', v_total);

    SET v_id_venta = LAST_INSERT_ID();

    -- Insertar detalle y actualizar stock
    SET i = 0;
    WHILE i < v_producto_count DO
        SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_productos, CONCAT('$[', i, '].id_producto')));
        SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_productos, CONCAT('$[', i, '].cantidad')));

        SELECT precio INTO v_precio FROM productos WHERE id_producto = v_producto_id;

        INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
        VALUES (v_id_venta, v_producto_id, v_cantidad, v_precio);

        UPDATE productos 
        SET stock = stock - v_cantidad 
        WHERE id_producto = v_producto_id;

        SET i = i + 1;
    END WHILE;

    -- Actualizar dirección del cliente si se suministra
    IF p_direccion_envio IS NOT NULL AND p_direccion_envio != '' THEN
        UPDATE clientes 
        SET direccion_envio = p_direccion_envio 
        WHERE id_cliente = p_id_cliente;
    END IF;

    COMMIT;

    -- Resultado
    SELECT v_id_venta AS id_venta, 
           'Venta procesada exitosamente' AS mensaje, 
           v_total AS total;
END;

-- ======================================================
-- 2. sp_AgregarNuevoProducto
-- Descripción: Agrega un nuevo producto validando categoría y proveedor.
-- Parámetros: p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku, p_id_categoria, p_id_proveedor.
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(150),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2),
    IN p_stock INT,
    IN p_sku VARCHAR(100),
    IN p_id_categoria INT,
    IN p_id_proveedor INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría especificada no existe';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = p_id_proveedor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor especificado no existe';
    END IF;
    
    INSERT INTO productos (nombre, descripcion, precio, costo, stock, sku, id_categoria, id_proveedor)
    VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku, p_id_categoria, p_id_proveedor);
    
    SELECT LAST_INSERT_ID() as id_producto, 'Producto agregado exitosamente' as mensaje;
    
    COMMIT;
END;

-- ======================================================
-- 3. sp_ActualizarDireccionCliente
-- Descripción: Actualiza la dirección de envío de un cliente existente.
-- Parámetros: p_id_cliente, p_nueva_direccion.
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_nueva_direccion TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente especificado no existe';
    END IF;
    
    UPDATE clientes 
    SET direccion_envio = p_nueva_direccion 
    WHERE id_cliente = p_id_cliente;
    
    COMMIT;
    
    SELECT 'Dirección actualizada exitosamente' as mensaje;
END;

-- ======================================================
-- 4. sp_ProcesarDevolucion
-- Descripción: Procesa devoluciones, ajusta stock y actualiza totales.
-- Parámetros: p_id_venta, p_id_producto, p_cantidad, p_motivo.
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_cantidad_vendida INT;
    DECLARE v_precio_unitario DECIMAL(10,2);
    DECLARE v_id_cliente INT;
    DECLARE v_monto_devolucion DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT dv.cantidad, dv.precio_unitario_congelado, v.id_cliente
    INTO v_cantidad_vendida, v_precio_unitario, v_id_cliente
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE dv.id_venta = p_id_venta AND dv.id_producto = p_id_producto;
    
    IF v_cantidad_vendida IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se encontró el detalle de venta especificado';
    END IF;
    
    IF p_cantidad > v_cantidad_vendida THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad a devolver excede la cantidad vendida';
    END IF;
    
    SET v_monto_devolucion = v_precio_unitario * p_cantidad;
    
    UPDATE productos 
    SET stock = stock + p_cantidad 
    WHERE id_producto = p_id_producto;
    
    UPDATE ventas 
    SET total = total - v_monto_devolucion 
    WHERE id_venta = p_id_venta;
    
    IF p_cantidad = v_cantidad_vendida THEN
        DELETE FROM detalle_ventas 
        WHERE id_venta = p_id_venta AND id_producto = p_id_producto;
    ELSE
        UPDATE detalle_ventas 
        SET cantidad = cantidad - p_cantidad 
        WHERE id_venta = p_id_venta AND id_producto = p_id_producto;
    END IF;
    
    COMMIT;
    
    SELECT 'Devolución procesada exitosamente' as mensaje, v_monto_devolucion as monto_devolucion;
END;

-- ======================================================
-- 5. sp_ObtenerHistorialComprasCliente
-- Descripción: Devuelve resumen de ventas y detalle por cliente.
-- Parámetros: p_id_cliente.
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT
)
BEGIN
    -- Resumen de ventas del cliente
    SELECT 
        v.id_venta,
        v.fecha_venta,
        v.estado,
        v.total,
        COUNT(dv.id_detalle) as cantidad_productos,
        SUM(dv.cantidad) as total_items
    FROM ventas v
    LEFT JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    WHERE v.id_cliente = p_id_cliente
    GROUP BY v.id_venta, v.fecha_venta, v.estado, v.total
    ORDER BY v.fecha_venta DESC;
    
    -- Detalle de productos por venta
    SELECT 
        v.id_venta,
        p.nombre as producto,
        p.descripcion,
        dv.cantidad,
        dv.precio_unitario_congelado as precio_unitario,
        (dv.cantidad * dv.precio_unitario_congelado) as subtotal,
        c.nombre as categoria
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC, p.nombre;
END;

-- ======================================================
-- 6. sp_AjustarNivelStock
-- Descripción: Ajusta el stock de un producto y reporta la diferencia.
-- Parámetros: p_id_producto, p_nuevo_stock, p_motivo.
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_nuevo_stock INT,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_diferencia INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT stock INTO v_stock_actual
    FROM productos 
    WHERE id_producto = p_id_producto;
    
    IF v_stock_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto especificado no existe';
    END IF;
    
    SET v_diferencia = p_nuevo_stock - v_stock_actual;
    
    UPDATE productos 
    SET stock = p_nuevo_stock 
    WHERE id_producto = p_id_producto;
    
    SELECT 'Stock ajustado exitosamente' as mensaje, 
           v_stock_actual as stock_anterior,
           p_nuevo_stock as stock_nuevo,
           v_diferencia as diferencia;
    
    COMMIT;
END;

-- ======================================================
-- 7. sp_EliminarClienteDeFormaSegura
-- Descripción: Anonimiza un cliente si no tiene ventas activas.
-- Parámetros: p_id_cliente.
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente especificado no existe';
    END IF;
    
    IF EXISTS (SELECT 1 FROM ventas WHERE id_cliente = p_id_cliente AND estado NOT IN ('Entregado', 'Cancelado')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar el cliente porque tiene ventas activas';
    END IF;
    
    UPDATE clientes 
    SET 
        nombre = 'Cliente',
        apellido = 'Eliminado',
        email = CONCAT('eliminado_', p_id_cliente, '@example.com'),
        contraseña = 'eliminado',
        direccion_envio = NULL
    WHERE id_cliente = p_id_cliente;
    
    COMMIT;
    
    SELECT 'Cliente anonimizado exitosamente' as mensaje;
END;

-- ======================================================
-- 8. sp_AplicarDescuentoPorCategoria
-- Descripción: Aplica un porcentaje de descuento a todos los productos de una categoría activa.
-- Parámetros: p_id_categoria, p_porcentaje_descuento (0 < x < 100).
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje_descuento DECIMAL(5,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF p_porcentaje_descuento <= 0 OR p_porcentaje_descuento >= 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El porcentaje de descuento debe estar entre 0 y 100';
    END IF;
    
    UPDATE productos 
    SET precio = precio * (1 - p_porcentaje_descuento / 100)
    WHERE id_categoria = p_id_categoria AND activo = TRUE;
    
    SELECT ROW_COUNT() as productos_actualizados, 
           CONCAT('Descuento del ', p_porcentaje_descuento, '% aplicado exitosamente') as mensaje;
    
    COMMIT;
END;

-- ======================================================
-- 9. sp_GenerarReporteMensualVentas
-- Descripción: Genera métricas y top ventas para un mes específico.
-- Parámetros: p_anio, p_mes.
CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    -- Resumen general del mes
    SELECT 
        COUNT(*) as total_ventas,
        SUM(total) as ingresos_totales,
        AVG(total) as promedio_venta,
        MIN(total) as venta_minima,
        MAX(total) as venta_maxima,
        COUNT(DISTINCT id_cliente) as clientes_unicos
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio AND MONTH(fecha_venta) = p_mes;
    
    -- Ventas por estado
    SELECT 
        estado,
        COUNT(*) as cantidad_ventas,
        SUM(total) as total_estado
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio AND MONTH(fecha_venta) = p_mes
    GROUP BY estado;
    
    -- Top 5 productos por unidades vendidas
    SELECT 
        p.nombre as producto,
        c.nombre as categoria,
        SUM(dv.cantidad) as total_vendido,
        SUM(dv.cantidad * dv.precio_unitario_congelado) as ingresos_generados
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE YEAR(v.fecha_venta) = p_anio AND MONTH(v.fecha_venta) = p_mes
    GROUP BY p.id_producto, p.nombre, c.nombre
    ORDER BY total_vendido DESC
    LIMIT 5;
    
    -- Ventas por día del mes
    SELECT 
        DATE(fecha_venta) as fecha,
        COUNT(*) as ventas_dia,
        SUM(total) as ingresos_dia
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio AND MONTH(fecha_venta) = p_mes
    GROUP BY DATE(fecha_venta)
    ORDER BY fecha;
END;

-- ======================================================
-- 10. sp_CambiarEstadoPedido
-- Descripción: Cambia el estado de una venta y repone stock si se cancela.
-- Parámetros: p_id_venta, p_nuevo_estado.
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(50)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_id_cliente INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT estado, id_cliente INTO v_estado_actual, v_id_cliente
    FROM ventas 
    WHERE id_venta = p_id_venta;
    
    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta especificada no existe';
    END IF;
    
    IF v_estado_actual = 'Cancelado' AND p_nuevo_estado != 'Cancelado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede cambiar el estado de una venta cancelada';
    END IF;
    
    UPDATE ventas 
    SET estado = p_nuevo_estado 
    WHERE id_venta = p_id_venta;
    
    -- Si la venta cambia a Cancelado, reponer stock
    IF p_nuevo_estado = 'Cancelado' AND v_estado_actual != 'Cancelado' THEN
        UPDATE productos p
        JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
        SET p.stock = p.stock + dv.cantidad
        WHERE dv.id_venta = p_id_venta;
    END IF;
    
    COMMIT;
    
    SELECT 'Estado actualizado exitosamente' as mensaje,
           v_estado_actual as estado_anterior,
           p_nuevo_estado as estado_nuevo,
           v_id_cliente as id_cliente;
END;

-- ======================================================
-- 11. sp_RegistrarNuevoCliente
-- Descripción: Registra un cliente nuevo validando email único.
-- Parámetros: p_nombre, p_apellido, p_email, p_contraseña, p_direccion_envio.
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(120),
    IN p_contraseña VARCHAR(255),
    IN p_direccion_envio TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF EXISTS (SELECT 1 FROM clientes WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El email ya está registrado';
    END IF;
    
    INSERT INTO clientes (nombre, apellido, email, contraseña, direccion_envio)
    VALUES (p_nombre, p_apellido, p_email, p_contraseña, p_direccion_envio);
    
    SELECT LAST_INSERT_ID() as id_cliente, 'Cliente registrado exitosamente' as mensaje;
    
    COMMIT;
END;

-- ======================================================
-- 12. sp_ObtenerDetallesProductoCompleto
-- Descripción: Devuelve ficha completa del producto, métricas y últimos clientes.
-- Parámetros: p_id_producto.
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT
)
BEGIN
    -- Datos básicos y proveedor/categoría
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.costo,
        p.stock,
        p.sku,
        p.fecha_creacion,
        p.activo,
        c.nombre as categoria,
        c.descripcion as descripcion_categoria,
        pr.nombre as proveedor,
        pr.email_contacto,
        pr.telefono_contacto
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.id_producto = p_id_producto;
    
    -- Métricas de venta del producto
    SELECT 
        COUNT(dv.id_detalle) as total_ventas,
        SUM(dv.cantidad) as unidades_vendidas,
        AVG(dv.precio_unitario_congelado) as precio_promedio_venta
    FROM detalle_ventas dv
    WHERE dv.id_producto = p_id_producto;
    
    -- Últimas ventas y clientes
    SELECT 
        v.fecha_venta,
        v.estado,
        dv.cantidad,
        dv.precio_unitario_congelado,
        CONCAT(c.nombre, ' ', c.apellido) as cliente
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE dv.id_producto = p_id_producto
    ORDER BY v.fecha_venta DESC
    LIMIT 10;
END;

-- ======================================================
-- 13. sp_FusionarCuentasCliente
-- Descripción: Fusiona ventas del cliente secundario al principal y anonimiza el secundario.
-- Parámetros: p_id_cliente_principal, p_id_cliente_secundario.
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT,
    IN p_id_cliente_secundario INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente_principal) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente principal no existe';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente_secundario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente secundario no existe';
    END IF;
    
    UPDATE ventas 
    SET id_cliente = p_id_cliente_principal 
    WHERE id_cliente = p_id_cliente_secundario;
    
    UPDATE clientes 
    SET 
        nombre = 'Fusionado',
        apellido = 'Con Cliente',
        email = CONCAT('fusionado_', p_id_cliente_secundario, '@example.com'),
        contraseña = 'fusionado',
        direccion_envio = NULL
    WHERE id_cliente = p_id_cliente_secundario;
    
    COMMIT;
    
    SELECT 'Cuentas fusionadas exitosamente' as mensaje;
END;

-- ======================================================
-- 14. sp_AsignarProductoAProveedor
-- Descripción: Asigna o cambia el proveedor de un producto.
-- Parámetros: p_id_producto, p_id_proveedor.
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT,
    IN p_id_proveedor INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM productos WHERE id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto especificado no existe';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = p_id_proveedor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor especificado no existe';
    END IF;
    
    UPDATE productos 
    SET id_proveedor = p_id_proveedor 
    WHERE id_producto = p_id_producto;
    
    COMMIT;
    
    SELECT 'Proveedor asignado exitosamente' as mensaje;
END;

-- ======================================================
-- 15. sp_BuscarProductos
-- Descripción: Búsqueda flexible de productos por término, categoría, precio y stock.
-- Parámetros: p_termino_busqueda, p_id_categoria, p_precio_min, p_precio_max, p_solo_con_stock.
CREATE PROCEDURE sp_BuscarProductos(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT,
    IN p_precio_min DECIMAL(10,2),
    IN p_precio_max DECIMAL(10,2),
    IN p_solo_con_stock BOOLEAN
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.sku,
        c.nombre as categoria,
        pr.nombre as proveedor
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.activo = TRUE
    AND (p_termino_busqueda IS NULL OR 
         p.nombre LIKE CONCAT('%', p_termino_busqueda, '%') OR 
         p.descripcion LIKE CONCAT('%', p_termino_busqueda, '%'))
    AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
    AND (p_precio_min IS NULL OR p.precio >= p_precio_min)
    AND (p_precio_max IS NULL OR p.precio <= p_precio_max)
    AND (NOT p_solo_con_stock OR p.stock > 0)
    ORDER BY p.nombre;
END;

-- ======================================================
-- 16. sp_ObtenerDashboardAdmin
-- Descripción: Resumen rápido para panel admin (ventas hoy, ingresos, productos bajo stock, top).
-- Parámetros: ninguno.
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    -- Indicadores principales
    SELECT 
        (SELECT COUNT(*) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) as ventas_hoy,
        (SELECT SUM(total) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) as ingresos_hoy,
        (SELECT COUNT(*) FROM clientes WHERE DATE(fecha_registro) = CURDATE()) as nuevos_clientes_hoy,
        (SELECT COUNT(*) FROM productos WHERE stock <= 5 AND activo = TRUE) as productos_bajo_stock,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Pendiente de Pago') as ventas_pendientes_pago,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Procesando') as ventas_procesando;
    
    -- Ventas últimos 7 días (serie)
    SELECT 
        DATE(fecha_venta) as fecha,
        COUNT(*) as ventas,
        SUM(total) as ingresos
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP BY DATE(fecha_venta)
    ORDER BY fecha DESC;
    
    -- Top categorías últimos 30 días
    SELECT 
        c.nombre as categoria,
        COUNT(dv.id_detalle) as ventas,
        SUM(dv.cantidad) as unidades_vendidas
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE v.fecha_venta >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY c.id_categoria, c.nombre
    ORDER BY unidades_vendidas DESC
    LIMIT 5;
    
    -- Top productos mes en curso
    SELECT 
        p.nombre as producto,
        SUM(dv.cantidad) as unidades_vendidas,
        SUM(dv.cantidad * dv.precio_unitario_congelado) as ingresos_generados
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE YEAR(v.fecha_venta) = YEAR(CURDATE()) AND MONTH(v.fecha_venta) = MONTH(CURDATE())
    GROUP BY p.id_producto, p.nombre
    ORDER BY unidades_vendidas DESC
    LIMIT 10;
END;

-- ======================================================
-- 17. sp_ProcesarPago
-- Descripción: Marca una venta como 'Procesando' si estaba en 'Pendiente de Pago'.
-- Parámetros: p_id_venta.
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT estado INTO v_estado_actual
    FROM ventas 
    WHERE id_venta = p_id_venta;
    
    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta especificada no existe';
    END IF;
    
    IF v_estado_actual != 'Pendiente de Pago' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no está pendiente de pago';
    END IF;
    
    UPDATE ventas 
    SET estado = 'Procesando' 
    WHERE id_venta = p_id_venta;
    
    COMMIT;
    
    SELECT 'Pago procesado exitosamente. Venta en estado: Procesando' as mensaje;
END;

-- ======================================================
-- 18. sp_AñadirReseñaProducto
-- Descripción: Valida que cliente compró y producto fue entregado antes de permitir reseña.
-- Parámetros: p_id_cliente, p_id_producto, p_calificacion (1-5), p_comentario.
CREATE PROCEDURE sp_AñadirReseñaProducto(
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_calificacion INT,
    IN p_comentario TEXT
)
BEGIN
    DECLARE v_ha_comprado BOOLEAN;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT COUNT(*) > 0 INTO v_ha_comprado
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE v.id_cliente = p_id_cliente 
    AND dv.id_producto = p_id_producto
    AND v.estado = 'Entregado';
    
    IF NOT v_ha_comprado THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no ha comprado este producto o no ha sido entregado';
    END IF;
    
    IF p_calificacion < 1 OR p_calificacion > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La calificación debe estar entre 1 y 5';
    END IF;
    
    -- Aquí se asume que existe una tabla reseñas; si no, se puede insertar en la tabla correspondiente.
    INSERT INTO reseñas (id_cliente, id_producto, calificacion, comentario, fecha_creacion)
    VALUES (p_id_cliente, p_id_producto, p_calificacion, p_comentario, NOW());
    
    COMMIT;
    
    SELECT 'Reseña agregada exitosamente' as mensaje;
END;

-- ======================================================
-- 19. sp_ObtenerProductosRelacionados
-- Descripción: Devuelve productos de la misma categoría o proveedor, activos y con stock.
-- Parámetros: p_id_producto.
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        'Misma categoría' as tipo_relacion
    FROM productos p
    WHERE p.id_categoria = (SELECT id_categoria FROM productos WHERE id_producto = p_id_producto)
    AND p.id_producto != p_id_producto
    AND p.activo = TRUE
    AND p.stock > 0
    
    UNION
    
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        'Mismo proveedor' as tipo_relacion
    FROM productos p
    WHERE p.id_proveedor = (SELECT id_proveedor FROM productos WHERE id_producto = p_id_producto)
    AND p.id_producto != p_id_producto
    AND p.activo = TRUE
    AND p.stock > 0
    
    ORDER BY precio DESC
    LIMIT 10;
END;

-- ======================================================
-- 20. sp_MoverProductosEntreCategorias
-- Procedimiento: Mover productos entre categorías
-- Función: Mueve una lista de productos (en formato JSON) a otra categoría.
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_ids_productos JSON,
    IN p_id_categoria_destino INT
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_producto_count INT;
    DECLARE v_producto_id INT;
    DECLARE v_mensaje TEXT;

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    -- Validar que la categoría destino exista
    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria_destino) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría destino no existe';
    END IF;
    
    -- Contar productos en el JSON
    SET v_producto_count = JSON_LENGTH(p_ids_productos);

    -- Recorrer productos
    WHILE i < v_producto_count DO
        SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_ids_productos, CONCAT('$[', i, ']')));
        
        -- Validar existencia del producto
        IF NOT EXISTS (SELECT 1 FROM productos WHERE id_producto = v_producto_id) THEN
            SET v_mensaje = CONCAT('El producto con ID ', v_producto_id, ' no existe');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
        
        -- Actualizar categoría
        UPDATE productos 
        SET id_categoria = p_id_categoria_destino 
        WHERE id_producto = v_producto_id;
        
        SET i = i + 1;
    END WHILE;
    
    COMMIT;

    -- Resultado final
    SELECT v_producto_count AS productos_movidos,
           CONCAT(v_producto_count, ' productos movidos exitosamente a la categoría ', p_id_categoria_destino) AS mensaje;
END;