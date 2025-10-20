USE e_commerce;

DROP DATABASE e_commerce;

-- ==============
-- #41 al #46
-- ==============

CREATE ROLE IF NOT EXISTS administrador_sistema;
CREATE ROLE IF NOT EXISTS gerente_marketing;
CREATE ROLE IF NOT EXISTS analista_datos;
CREATE ROLE IF NOT EXISTS empleado_inventario;
CREATE ROLE IF NOT EXISTS atencion_cliente;
CREATE ROLE IF NOT EXISTS auditor_financiero;


-- Dar todos los privilegios al administrador de sistema
GRANT ALL PRIVILEGES ON e_commerce.* TO administrador_sistema;

-- gerente de marketing con acceso de solo lectura a ventas y clientes.

GRANT SELECT ON e_commerce.ventas TO gerente_marketing;
GRANT SELECT ON e_commerce.clientes TO gerente_marketing;

-- analista de datos solo lectura de todas las tablas

GRANT SELECT ON e_commerce.* TO analista_datos;

-- empleado inventario puede modificar stock y ubicación de productos

GRANT SELECT, UPDATE (stock, id_proveedor) ON e_commerce.productos TO empleado_inventario;

-- atencion al cluinte pueda ver clientes y ventas, pero no modificar precios.

GRANT SELECT ON e_commerce.clientes TO atencion_cliente;
GRANT SELECT ON e_commerce.ventas TO atencion_cliente;
GRANT SELECT ON e_commerce.detalle_ventas TO atencion_cliente;


-- auditor financiero con acceso de solo lectura a ventas, productos y logs de precios.

GRANT SELECT ON e_commerce.ventas TO auditor_financiero;
GRANT SELECT ON e_commerce.productos TO auditor_financiero;

-- Hay que crear una tabla que loguee precios

CREATE TABLE log_precios(
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_modifico VARCHAR(100) NOT NULL,
    motivo_cambio VARCHAR(255) NULL,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

GRANT SELECT ON e_commerce.log_precios TO auditor_financiero; 


-- #47 crear user admin_user y asignar rol admin

CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Admin#2025';
GRANT administrador_sistema TO 'admin_user'@'localhost';
SET DEFAULT ROLE administrador_sistema TO 'admin_user'@'localhost';


-- 48 crear user marketing_user y asignar rol marketing

CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' IDENTIFIED BY 'Marketing#2025';
GRANT gerente_marketing TO 'marketing_user'@'localhost';
SET DEFAULT ROLE gerente_marketing TO 'marketing_user'@'localhost';

-- 49 crear user inventory_user y asignar rol inventario

CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'Inventario#2025';
GRANT empleado_inventario TO 'inventory_user'@'localhost';
SET DEFAULT ROLE empleado_inventario TO 'inventory_user'@'localhost';

-- 50 crear user support_user y asignar rol atencion al cliente

CREATE USER IF NOT EXISTS 'support_user'@'localhost' IDENTIFIED BY 'Soporte#2025';
GRANT atencion_cliente TO 'support_user'@'localhost';
SET DEFAULT ROLE atencion_cliente TO 'support_user'@'localhost';


-- #51 Impedir que el rol Analista_Datos pueda ejecutar comandos DELETE o TRUNCATE.

REVOKE DELETE, TRUNCATE ON e_commerce.* FROM analista_datos;

-- #52 Otorgar a gerente_marketing permiso para ejecutar procedimientos de reportes

GRANT EXECUTE ON PROCEDURE e_commerce.sp_GenerarReporteMensualVentas TO gerente_marketing; -- procedimiento esta unos puntos mas adelante

-- #53 Crear vista v_info_clientes_basica y dar acceso al rol atencion_cliente

CREATE OR REPLACE VIEW e_commerce.v_info_clientes_basica AS
SELECT
  id_cliente,
  -- Nombre completo capitalizado (Primera letra mayúscula, resto minúscula)
  CONCAT(
    UCASE(LEFT(nombre,1)), LOWER(SUBSTRING(nombre,2)),
    ' ',
    UCASE(LEFT(apellido,1)), LOWER(SUBSTRING(apellido,2))
  ) AS nombre_completo,
  -- Email parcialmente enmascarado: muestra primera letra y dominio (p.ej. j****@dominio.com)
  CASE
    WHEN email IS NULL THEN NULL
    WHEN LOCATE('@', email) = 0 THEN '***'
    WHEN LOCATE('@', email) <= 2 THEN
      CONCAT(REPEAT('*', GREATEST(1, LOCATE('@', email)-1)), SUBSTRING(email, LOCATE('@', email)))
    ELSE
      CONCAT(
        LEFT(email,1),
        REPEAT('*', GREATEST(1, LOCATE('@', email) - 2)),
        SUBSTRING(email, LOCATE('@', email))
      )
  END AS email_mascara,
  -- No incluimos 'contraseña' ni 'direccion_envio' (datos sensibles).
  fecha_registro
FROM e_commerce.clientes;

GRANT SELECT ON e_commerce.v_info_clientes_basica TO atencion_cliente;

-- #54 Revocar permiso de UPDATE sobre la columna precio al rol empleado_inventario

REVOKE UPDATE (precio) ON e_commerce.productos FROM empleado_inventario;

-- #55 implementa politica de contra

INSTALL PLUGIN validate_password SONAME 'validate_password.dll';
-- plugin para validar contras .dll windows .so linux

SET GLOBAL validate_password.policy = MEDIUM;
SET GLOBAL validate_password.length = 8;
-- requisitos minimos de la contraseña

-- #56 Asegurar que el usuario root no pueda conectarse remotamente

UPDATE mysql.user SET Host='localhost' WHERE User='root';
FLUSH PRIVILEGES;

-- #57 Crear rol Visitante (solo lectura en productos)
CREATE ROLE IF NOT EXISTS visitante;
-- visitante solo puede ver los productos

GRANT SELECT ON e_commerce.productos TO visitante;


-- #58 Limitar número de consultas por hora para analista_datos

ALTER USER 'analista_datos'@'localhost' WITH MAX_QUERIES_PER_HOUR 500;

-- #59 Asegurar que usuarios solo vean ventas de su sucursal

-- para lograrlo se deberia agregar una id sucursal para identificar que informacion se debe mostrar
-- agragamos una column id_sucursal
ALTER TABLE ventas ADD COLUMN id_sucursal INT NOT NULL;

CREATE OR REPLACE VIEW e_commerce.v_ventas_por_sucursal AS
SELECT * FROM e_commerce.ventas WHERE id_sucursal = CURRENT_USER();

GRANT SELECT ON e_commerce.v_ventas_por_sucursal TO empleado_sucursal;
