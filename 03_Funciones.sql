USE e_commerce;

DROP DATABASE e_commerce;

-- =============================================================
-- FUNCIONES DEFINIDAS POR EL USUARIO (UDFs)
-- =============================================================

-- 1. Calcula el monto total de una venta específica.
CREATE FUNCTION fn_calcular_total_venta(p_id_venta INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN (SELECT SUM(subtotal) FROM detalle_ventas WHERE id_venta = p_id_venta);

-- 2. Verifica si hay stock suficiente para un producto.
CREATE FUNCTION fn_verificar_disponibilidad_stock(p_id_producto INT, p_cantidad INT)
RETURNS BOOLEAN
DETERMINISTIC
RETURN (SELECT stock >= p_cantidad FROM productos WHERE id_producto = p_id_producto);

-- 3. Devuelve el precio de un producto.
CREATE FUNCTION fn_obtener_precio_producto(p_id_producto INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN (SELECT precio FROM productos WHERE id_producto = p_id_producto);

-- 4. Calcula la edad de un cliente a partir de su fecha de nacimiento.
CREATE FUNCTION fn_calcular_edad_cliente(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
RETURN TIMESTAMPDIFF(YEAR, (SELECT fecha_nacimiento FROM clientes WHERE id_cliente = p_id_cliente), CURDATE());

-- 5. Devuelve el nombre completo de un cliente con formato estandarizado.
CREATE FUNCTION fn_formatear_nombre_completo(p_id_cliente INT)
RETURNS VARCHAR(100)
DETERMINISTIC
RETURN (SELECT CONCAT(UCASE(LEFT(nombre,1)), LOWER(SUBSTRING(nombre,2)), ' ', UCASE(LEFT(apellido,1)), LOWER(SUBSTRING(apellido,2))) FROM clientes WHERE id_cliente = p_id_cliente);

-- 6. Devuelve TRUE si un cliente es nuevo (últimos 30 días).
CREATE FUNCTION fn_es_cliente_nuevo(p_id_cliente INT)
RETURNS BOOLEAN
DETERMINISTIC
RETURN (SELECT DATEDIFF(CURDATE(), fecha_registro) <= 30 FROM clientes WHERE id_cliente = p_id_cliente);

-- 7. Calcula el costo de envío basado en el peso total.
CREATE FUNCTION fn_calcular_costo_envio(p_peso_total DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN p_peso_total * 5.0;

-- 8. Aplica un porcentaje de descuento a un monto dado.
CREATE FUNCTION fn_aplicar_descuento(p_monto DECIMAL(10,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN p_monto - (p_monto * p_porcentaje / 100);

-- 9. Devuelve la fecha de la última compra de un cliente.
CREATE FUNCTION fn_obtener_ultima_fecha_compra(p_id_cliente INT)
RETURNS DATE
DETERMINISTIC
RETURN (SELECT MAX(fecha_venta) FROM ventas WHERE id_cliente = p_id_cliente);

-- 10. Verifica si un email tiene formato válido.
CREATE FUNCTION fn_validar_formato_email(p_email VARCHAR(100))
RETURNS BOOLEAN
DETERMINISTIC
RETURN p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';

-- 11. Devuelve el nombre de la categoría de un producto.
CREATE FUNCTION fn_obtener_nombre_categoria(p_id_producto INT)
RETURNS VARCHAR(50)
DETERMINISTIC
RETURN (SELECT c.nombre_categoria FROM productos p JOIN categorias c ON p.id_categoria = c.id_categoria WHERE p.id_producto = p_id_producto);

-- 12. Cuenta el número de ventas realizadas por un cliente.
CREATE FUNCTION fn_contar_ventas_cliente(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
RETURN (SELECT COUNT(*) FROM ventas WHERE id_cliente = p_id_cliente);

-- 13. Calcula los días desde la última compra de un cliente.
CREATE FUNCTION fn_calcular_dias_desde_ultima_compra(p_id_cliente INT)
RETURNS INT
DETERMINISTIC
RETURN DATEDIFF(CURDATE(), (SELECT MAX(fecha_venta) FROM ventas WHERE id_cliente = p_id_cliente));

-- 14. Determina el estado de lealtad de un cliente según su gasto total.
CREATE FUNCTION fn_determinar_estado_lealtad(p_id_cliente INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE total_gasto DECIMAL(10,2);
    SET total_gasto = (SELECT SUM(total) FROM ventas WHERE id_cliente = p_id_cliente);
    RETURN CASE
        WHEN total_gasto >= 5000 THEN 'Oro'
        WHEN total_gasto >= 2000 THEN 'Plata'
        ELSE 'Bronce'
    END;
END;

-- 15. Genera un código SKU único para un producto.
CREATE FUNCTION fn_generar_sku(p_nombre_producto VARCHAR(100), p_id_categoria INT)
RETURNS VARCHAR(50)
DETERMINISTIC
RETURN CONCAT('SKU-', p_id_categoria, '-', LEFT(REPLACE(UPPER(p_nombre_producto), ' ', ''), 5));

-- 16. Calcula el IVA sobre el total de una venta.
CREATE FUNCTION fn_calcular_iva(p_total DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN p_total * 0.19;

-- 17. Suma el stock total de una categoría específica.
CREATE FUNCTION fn_obtener_stock_total_por_categoria(p_id_categoria INT)
RETURNS INT
DETERMINISTIC
RETURN (SELECT SUM(stock) FROM productos WHERE id_categoria = p_id_categoria);

-- 18. Calcula la fecha estimada de entrega según la ciudad del cliente.
CREATE FUNCTION fn_estimar_fecha_entrega(p_ciudad VARCHAR(100))
RETURNS DATE
DETERMINISTIC
RETURN DATE_ADD(CURDATE(), INTERVAL (CASE
    WHEN p_ciudad = 'Bogotá' THEN 2
    WHEN p_ciudad = 'Medellín' THEN 3
    ELSE 5
END) DAY);

-- 19. Convierte un monto a otra moneda usando una tasa fija.
CREATE FUNCTION fn_convertir_moneda(p_monto DECIMAL(10,2), p_tasa DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
RETURN p_monto * p_tasa;

-- 20. Verifica la complejidad de una contraseña (mayúscula, minúscula, número, símbolo).
CREATE FUNCTION fn_validar_complejidad_contrasena(p_contrasena VARCHAR(50))
RETURNS BOOLEAN
DETERMINISTIC
RETURN p_contrasena REGEXP '^(?=.[A-Z])(?=.[a-z])(?=.[0-9])(?=.[!@#\\$%\\^&\\*]).{8,}$';


SELECT fn_calcular_total_venta(1);
SELECT fn_verificar_disponibilidad_stock(1, 2);
SELECT fn_obtener_precio_producto(2);
SELECT fn_calcular_edad_cliente(1);
SELECT fn_formatear_nombre_completo(2);
SELECT fn_es_cliente_nuevo(3);
SELECT fn_calcular_costo_envio(15.5);
SELECT fn_aplicar_descuento(1000, 10);
SELECT fn_obtener_ultima_fecha_compra(2);
SELECT fn_validar_formato_email('usuario@dominio.com');
SELECT fn_obtener_nombre_categoria(1);
SELECT fn_contar_ventas_cliente(1);
SELECT fn_calcular_dias_desde_ultima_compra(1);
SELECT fn_determinar_estado_lealtad(2);
SELECT fn_generar_sku('Camisa Azul', 2);
SELECT fn_calcular_iva(2000);
SELECT fn_obtener_stock_total_por_categoria(1);
SELECT fn_estimar_fecha_entrega('Cali');
SELECT fn_convertir_moneda(100, 4000);
SELECT fn_validar_complejidad_contrasena('Pass@2024');
