USE e_commerce;

DROP DATABASE e_commerce;

-- ===========================================
--  Consultas Avanzadas
-- ===========================================

-- Consulta 1: Top 10 Productos Más Vendidos.
SELECT 
    p.nombre AS producto,
    SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos
FROM detalle_ventas dv
JOIN productos p ON dv.id_producto = p.id_producto
GROUP BY p.nombre
ORDER BY ingresos DESC
LIMIT 10; 

-- ======================================================================================

-- Consulta 2: Productos con Bajas Ventas
WITH ventas AS (
    SELECT 
        p.id_producto,
        p.nombre,
        -- COALESCE reemplaza los NULL con 0
        COALESCE(SUM(dv.cantidad), 0) AS total_vendido
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto, p.nombre
)
SELECT 
    id_producto,
    nombre,
    total_vendido
FROM (
    SELECT 
        vpp.*,
        NTILE(10) OVER (ORDER BY total_vendido ASC) AS decil
    FROM ventas vpp
) t
WHERE decil = 1  -- decil 1 = el 10% con menos ventas
ORDER BY total_vendido ASC;

-- ======================================================================================

-- Consulta 3: Clientes VIP
SELECT 
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    SUM(v.total) AS gasto_total
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
GROUP BY cliente
ORDER BY gasto_total DESC
LIMIT 5;

-- ======================================================================================

-- Consulta 4: Análisis de Ventas Mensuales
SELECT 
    EXTRACT(YEAR FROM fecha_venta) AS año,
    MONTHNAME(fecha_venta) AS nombre_mes,
    SUM(total) AS ventas_totales
FROM ventas
GROUP BY año, MONTH(fecha_venta), nombre_mes
ORDER BY año, MONTH(fecha_venta);

-- ======================================================================================

-- Consulta 5: Crecimiento de Clientes
SELECT 
    EXTRACT(YEAR FROM fecha_registro) AS año,
    EXTRACT(QUARTER FROM fecha_registro) AS trimestre,
    COUNT(*) AS nuevos_clientes
FROM clientes
GROUP BY año, trimestre
ORDER BY año, trimestre;

-- ======================================================================================

-- Consulta 6: Tasa de Compra Repetida
WITH compras_por_cliente AS (
    SELECT 
        id_cliente,
        COUNT(*) AS total_compras
    FROM ventas
    GROUP BY id_cliente
)
SELECT 
    COUNT(*) AS total_clientes,
    SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) AS clientes_recurrentes,
    SUM(CASE WHEN total_compras = 1 THEN 1 ELSE 0 END) AS clientes_unicos,
    ROUND(AVG(total_compras), 2) AS promedio_compras_por_cliente,
    ROUND(SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS tasa_repeticion_porcentaje
FROM compras_por_cliente;

-- ======================================================================================

-- Consulta 7: Productos Comprados Juntos Frecuentemente
SELECT 
    p1.nombre AS producto_1,
    p2.nombre AS producto_2,
    COUNT(*) AS frecuencia_compra
FROM detalle_ventas a
JOIN detalle_ventas b 
    ON a.id_venta = b.id_venta 
    AND a.id_producto < b.id_producto  -- evita duplicados (ej: producto A con B y B con A)
JOIN productos p1 ON a.id_producto = p1.id_producto
JOIN productos p2 ON b.id_producto = p2.id_producto
GROUP BY producto_1, producto_2
ORDER BY frecuencia_compra DESC
LIMIT 10;

-- ======================================================================================

-- Consulta 8: Rotación de Inventario
SELECT 
    c.nombre AS categoria,
    SUM(dv.cantidad) AS productos_vendidos,
    SUM(p.stock) AS stock_total,
    ROUND(SUM(dv.cantidad) / NULLIF(SUM(p.stock), 0), 2) AS rotacion
FROM detalle_ventas dv
JOIN productos p ON p.id_producto = dv.id_producto
JOIN categorias c ON c.id_categoria = p.id_categoria
GROUP BY c.nombre;

-- ======================================================================================

-- Consulta 9: Productos que Necesitan Reabastecimiento
SELECT nombre, stock
FROM productos
WHERE stock < 10; -- umbral mínimo = 10

-- ======================================================================================

-- Consulta 10: Análisis de Carrito Abandonado (Simulado)
-- ===========================
-- CREACIÓN TABLA CARRITO
-- ===========================
CREATE TABLE carrito (
    id_carrito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    fecha_agregado DATETIME DEFAULT NOW(),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- ===========================
-- INSERCIÓN TABLA CARRITO
-- ===========================
INSERT INTO carrito (id_cliente, id_producto, cantidad, fecha_agregado)
VALUES
(1, 2, 1, '2025-10-10 14:32:00'), 
(1, 5, 2, '2025-10-11 09:20:00'), 
(2, 3, 3, '2025-10-12 11:45:00'),
(2, 4, 1, '2025-10-12 11:50:00'), 
(3, 6, 1, '2025-10-13 16:10:00'), 
(3, 7, 2, '2025-10-13 16:15:00'), 
(1, 8, 1, '2025-10-13 17:00:00'), 
(2, 1, 1, '2025-10-13 18:00:00');  

DROP TABLE carrito;

SELECT 
    c.id_carrito,
    cli.nombre AS cliente,
    p.nombre AS producto,
    c.cantidad,
    c.fecha_agregado
FROM carrito c
JOIN clientes cli ON c.id_cliente = cli.id_cliente
JOIN productos p ON c.id_producto = p.id_producto
ORDER BY c.fecha_agregado DESC;

-- ======================================================================================

-- Consulta 11: Rendimiento de Proveedores
SELECT 
    pr.nombre AS proveedor,
    SUM(dv.cantidad * dv.precio_unitario_congelado) AS total_ventas
FROM detalle_ventas dv
JOIN productos p ON p.id_producto = dv.id_producto
JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
GROUP BY pr.nombre
ORDER BY total_ventas DESC;

-- ======================================================================================

-- Consulta 12: Análisis Geográfico de Ventas
SELECT 
    c.direccion_envio AS ciudad,
    SUM(v.total) AS ventas_totales
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
GROUP BY c.direccion_envio
ORDER BY ventas_totales DESC;

-- ======================================================================================

-- Consulta 13: Ventas por Hora del Día
SELECT 
    EXTRACT(HOUR FROM fecha_venta) AS hora,
    CONCAT(
        LPAD(EXTRACT(HOUR FROM fecha_venta), 2, '0'), ':00 - ',
        LPAD(EXTRACT(HOUR FROM fecha_venta) + 1, 2, '0'), ':00'
    ) AS franja_horaria,
    COUNT(*) AS total_ventas,
    SUM(total) AS monto_total,
    ROUND(SUM(total) * 100.0 / (SELECT SUM(total) FROM ventas), 2) AS porcentaje_participacion
FROM ventas
GROUP BY hora, franja_horaria
ORDER BY hora;

-- ======================================================================================

-- Consulta 14: Impacto de Promociones

-- ===========================
-- CREACIÓN TABLA PROMOCIONES
-- ===========================
CREATE TABLE promociones (
  id_promocion SERIAL PRIMARY KEY,
  id_producto INT REFERENCES productos(id_producto),
  fecha_inicio DATE,
  fecha_fin DATE,
  descuento DECIMAL(5,2)
);

DROP TABLE promociones;

-- ===========================
-- INSERSIÓN TABLA PROMOCIONES
-- ===========================
INSERT INTO promociones (id_producto, fecha_inicio, fecha_fin, descuento)
VALUES
(1, '2025-09-01', '2025-09-15', 10.00),   
(2, '2025-09-10', '2025-09-30', 15.00),   
(3, '2025-08-20', '2025-09-05', 20.00),   
(4, '2025-09-25', '2025-10-10', 12.50),  
(5, '2025-10-01', '2025-10-20', 18.00),   
(6, '2025-10-05', '2025-10-25', 10.00),   
(7, '2025-09-15', '2025-09-30', 25.00),   
(8, '2025-10-10', '2025-10-30', 15.00);   

SELECT 
    p.id_promocion,
    pr.nombre AS producto,
    CONCAT(CAST(p.descuento AS CHAR), '%') AS descuento,
    COALESCE(
        (SELECT SUM(v.total)
         FROM ventas v
         WHERE v.fecha_venta BETWEEN DATE_SUB(p.fecha_inicio, INTERVAL 10 DAY)
                                 AND DATE_SUB(p.fecha_inicio, INTERVAL 1 DAY)
        ), 0) AS ventas_antes,
    COALESCE(
        (SELECT SUM(v.total)
         FROM ventas v
         WHERE v.fecha_venta BETWEEN p.fecha_inicio AND p.fecha_fin
        ), 0) AS ventas_durante,
    COALESCE(
        (SELECT SUM(v.total)
         FROM ventas v
         WHERE v.fecha_venta BETWEEN DATE_ADD(p.fecha_fin, INTERVAL 1 DAY)
                                 AND DATE_ADD(p.fecha_fin, INTERVAL 10 DAY)
        ), 0) AS ventas_despues
FROM promociones p
JOIN productos pr ON p.id_producto = pr.id_producto
ORDER BY p.fecha_inicio;

-- ======================================================================================

-- Consulta 15: Análisis de Cohort
WITH primera_compra AS (
    SELECT 
        id_cliente,
        MIN(DATE_FORMAT(fecha_venta, '%Y-%m')) AS mes_corte
    FROM ventas
    GROUP BY id_cliente
),
compras_por_mes AS (
    SELECT 
        id_cliente,
        DATE_FORMAT(fecha_venta, '%Y-%m') AS mes_compra
    FROM ventas
),
cohort AS (
    SELECT 
        p.mes_corte,
        c.mes_compra,
        COUNT(DISTINCT c.id_cliente) AS clientes_activos
    FROM primera_compra p
    JOIN compras_por_mes c ON p.id_cliente = c.id_cliente
    GROUP BY p.mes_corte, c.mes_compra
)
SELECT 
    mes_corte,
    mes_compra,
    clientes_activos,
    ROUND(clientes_activos * 100.0 / 
        MAX(CASE WHEN mes_corte = mes_compra THEN clientes_activos END) 
        OVER (PARTITION BY mes_corte), 2
    ) AS tasa_retencion
FROM cohort
ORDER BY mes_corte, mes_compra;

-- ======================================================================================

-- Consulta 16: Margen de Beneficio por Producto
SELECT 
    p.nombre AS producto,
    p.precio AS precio_venta,
    p.costo AS costo_unitario,
    (p.precio - p.costo) AS ganancia_unidad,
    ROUND(((p.precio - p.costo) / p.precio) * 100, 2) AS margen_porcentaje,
    SUM(dv.cantidad * (dv.precio_unitario_congelado - p.costo)) AS beneficio_total
FROM productos p
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre, p.precio, p.costo
ORDER BY beneficio_total DESC;

-- ======================================================================================

-- Consulta 17: Tiempo Promedio Entre Compras por cliente

WITH diferencias AS (
    SELECT 
        id_cliente,
        fecha_venta,
        LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta) AS fecha_anterior
    FROM ventas
)
SELECT 
    id_cliente,
    ROUND(AVG(DATEDIFF(fecha_venta, fecha_anterior)), 2) AS dias_promedio_entre_compras
FROM diferencias
WHERE fecha_anterior IS NOT NULL
GROUP BY id_cliente
ORDER BY dias_promedio_entre_compras;

-- ======================================================================================

-- Consulta 18: Productos Más Vistos vs. Comprados

CREATE TABLE visitas_productos (
  id_visita SERIAL PRIMARY KEY,
  id_cliente INT REFERENCES clientes(id_cliente),
  id_producto INT REFERENCES productos(id_producto),
  fecha_visita TIMESTAMP DEFAULT NOW()
);

-- INSERCIÓN DATOS
CREATE PROCEDURE InsercionVisitasProductos()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE total_clientes INT;
    DECLARE total_productos INT;

    SELECT COUNT(*) INTO total_clientes FROM clientes;
    SELECT COUNT(*) INTO total_productos FROM productos;

    WHILE i <= 80 DO
        INSERT INTO visitas_productos (id_cliente, id_producto, fecha_visita)
        VALUES (
            FLOOR(1 + RAND() * total_clientes), 
            FLOOR(1 + RAND() * total_productos), 
            DATE_ADD('2025-09-01', INTERVAL FLOOR(RAND() * 60) DAY) 
        );
        SET i = i + 1;
    END WHILE;
END;

DROP PROCEDURE IF EXISTS InsercionVisitasProductos;
TRUNCATE TABLE visitas_productos;
CALL InsercionVisitasProductos();
SELECT * FROM visitas_productos;

-- CONSULTA

WITH 
-- cuántas veces fue visto cada producto
vistas AS (
    SELECT 
        p.id_producto,
        p.nombre AS producto,
        COUNT(vp.id_visita) AS total_vistas
    FROM productos p
    LEFT JOIN visitas_productos vp ON p.id_producto = vp.id_producto
    GROUP BY p.id_producto, p.nombre
),

-- cuántas veces fue comprado cada producto
compras AS (
    SELECT 
        p.id_producto,
        COUNT(dv.id_detalle) AS total_compras
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto
)

-- Combinación de ambas métricas en una sola vista
SELECT 
    v.producto,
    v.total_vistas,
    COALESCE(c.total_compras, 0) AS total_compras,
    (v.total_vistas - COALESCE(c.total_compras, 0)) AS diferencia,
    ROUND((COALESCE(c.total_compras, 0) / NULLIF(v.total_vistas, 0)) * 100, 2) AS tasa_conversion
FROM vistas v
LEFT JOIN compras c ON v.id_producto = c.id_producto
ORDER BY v.total_vistas DESC;

-- ======================================================================================

-- Consulta 19: Segmentación de Clientes (RFM)
WITH rfm AS (
    SELECT 
        v.id_cliente,
        DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia_dias,
        COUNT(v.id_venta) AS frecuencia,
        SUM(v.total) AS monetario
    FROM ventas v
    GROUP BY v.id_cliente
)
SELECT 
    r.id_cliente,
    r.recencia_dias,
    r.frecuencia,
    FORMAT(r.monetario, 2, 'de_DE') AS monetario
FROM rfm r
ORDER BY r.id_cliente;

-- ======================================================================================

-- Consulta 20: Predicción de Demanda Simple
WITH ventas_mensuales AS (
    SELECT 
        c.nombre AS categoria,
        DATE_FORMAT(v.fecha_venta, '%Y-%m') AS mes,
        SUM(dv.cantidad) AS unidades_vendidas
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN categorias c ON p.id_categoria = c.id_categoria
    GROUP BY c.nombre, DATE_FORMAT(v.fecha_venta, '%Y-%m')
),
promedio_categoria AS (
    SELECT 
        categoria,
        ROUND(AVG(unidades_vendidas), 2) AS promedio_mensual
    FROM ventas_mensuales
    GROUP BY categoria
)
SELECT 
    categoria,
    promedio_mensual AS prediccion_proximo_mes,
    DATE_FORMAT(DATE_ADD(LAST_DAY(CURDATE()), INTERVAL 1 DAY), '%Y-%m') AS mes_predicho
FROM promedio_categoria
ORDER BY categoria;


