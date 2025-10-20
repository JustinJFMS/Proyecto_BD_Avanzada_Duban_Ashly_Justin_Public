-- ============================================
-- CREACIÓN DE BASE DE DATOS
-- ============================================
CREATE DATABASE IF NOT EXISTS e_commerce;
USE e_commerce;

DROP DATABASE e_commerce;

-- ============================================
-- TABLA: Categorías
-- ============================================
CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);

-- ============================================
-- TABLA: Proveedores
-- ============================================
CREATE TABLE proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(120) UNIQUE,
    telefono_contacto VARCHAR(50)
);

-- ============================================
-- TABLA: Productos
-- ============================================
CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL CHECK (precio > 0),
    costo DECIMAL(10,2) NOT NULL CHECK (costo >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    sku VARCHAR(100) NOT NULL UNIQUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    id_categoria INT NOT NULL,
    id_proveedor INT NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
);

-- ============================================
-- TABLA: Clientes
-- ============================================
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    contraseña VARCHAR(255) NOT NULL,
    direccion_envio TEXT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLA: Ventas 
-- ============================================
CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_venta DATETIME,
    estado ENUM('Pendiente de Pago','Procesando','Enviado','Entregado','Cancelado') NOT NULL,
    total DECIMAL(12,2) NOT NULL CHECK (total >= 0),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

DROP TABLE ventas;

-- ============================================
-- TABLA: Detalle de Ventas 
-- ============================================
CREATE TABLE detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario_congelado DECIMAL(10,2) NOT NULL CHECK (precio_unitario_congelado > 0),
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    UNIQUE (id_venta, id_producto) -- evita duplicar el mismo producto en una misma venta
);

DROP TABLE detalle_ventas;

-- ============================================
-- INSERCION DE DATOS
-- ===========================================
INSERT INTO categorias (nombre, descripcion) VALUES
('Electrónica', 'Dispositivos electrónicos y accesorios'),
('Ropa', 'Prendas de vestir para hombres, mujeres y niños'),
('Hogar', 'Artículos para el hogar y la cocina'),
('Deportes', 'Artículos deportivos y de entrenamiento'),
('Juguetería', 'Juguetes educativos y recreativos para todas las edades'),
('Computación', 'Equipos de cómputo, periféricos y accesorios'),
('Belleza', 'Productos de cuidado personal y cosmética'),
('Oficina', 'Artículos de papelería y suministros de oficina');

-- Verificar los datos
SELECT * FROM categorias;
-- Limpiar la tabla
TRUNCATE TABLE categorias;

-- ============================================
-- TABLA: Proveedores
-- ============================================
INSERT INTO proveedores (nombre, email_contacto, telefono_contacto) VALUES
('TechWorld S.A.', 'contacto@techworld.com', '3204567890'),
('ModaTotal Ltda.', 'ventas@modatotal.com', '3109876543'),
('CasaFácil SAS', 'info@casafacil.com', '3006543210'),
('SportMax Colombia', 'soporte@sportmax.co', '3121234567'),
('Juguetelandia S.A.', 'ventas@juguetelandia.com', '3101122334'),
('CompuStore Ltda.', 'contacto@compustore.co', '3145566778'),
('BellezaPlus', 'info@bellezaplusc.com', '3016677889'),
('OfiMarket SAS', 'ventas@ofimarket.com', '3009988776');

SELECT * FROM proveedores;
TRUNCATE TABLE proveedores;

-- ============================================
-- TABLA: Productos
-- ============================================

-- Electrónica - Proveedor 1 (TechWorld S.A.)
-- Ropa - Proveedor 2 (ModaTotal Ltda.)
-- Hogar - Proveedor 3 (CasaFácil SAS)
-- Deportes - Proveedor 4 (SportMax Colombia)
-- Juguetería - Proveedor 5 (Juguetelandia S.A.)
-- Computación - Proveedor 6 (CompuStore Ltda.)
-- Belleza - Proveedor 7 (BellezaPlus)
-- Oficina - Proveedor 8 (OfiMarket SAS)

INSERT INTO productos (nombre, descripcion, precio, costo, stock, sku, id_categoria, id_proveedor)
VALUES
('Smartphone Galaxy X', 'Teléfono inteligente con cámara de 108MP y pantalla AMOLED', 1800000, 1200000, 25, 'SKU-ELEC-001', 1, 1),
('Audífonos Bluetooth AirSound', 'Audífonos inalámbricos con cancelación de ruido', 250000, 150000, 40, 'SKU-ELEC-002', 1, 1),
('Tablet UltraTab 10"', 'Pantalla FullHD con 128GB de almacenamiento', 950000, 650000, 18, 'SKU-ELEC-003', 1, 1),
('Smartwatch FitLife', 'Reloj inteligente con monitoreo de salud', 480000, 300000, 28, 'SKU-ELEC-004', 1, 1),
('Cámara Deportiva ActionX', 'Cámara sumergible 4K con estabilizador', 700000, 500000, 20, 'SKU-ELEC-005', 1, 1),
('Tablet SamsungTab 12"', 'Pantalla FullHD con 256GB de almacenamiento', 1000000, 850000, 8, 'SKU-ELEC-006', 1, 1),
('Camiseta Básica Blanca', 'Camiseta de algodón 100% unisex', 35000, 15000, 80, 'SKU-ROPA-001', 2, 2),
('Pantalón Deportivo', 'Pantalón tipo jogger con bolsillos laterales', 85000, 40000, 60, 'SKU-ROPA-002', 2, 2),
('Chaqueta Casual Hombre', 'Chaqueta de mezclilla azul con cierre metálico', 160000, 90000, 35, 'SKU-ROPA-003', 2, 2),
('Vestido Floral Mujer', 'Vestido veraniego de tela liviana', 120000, 70000, 22, 'SKU-ROPA-004', 2, 2),
('Gorra Urbana', 'Gorra ajustable con diseño moderno', 45000, 20000, 55, 'SKU-ROPA-005', 2, 2),
('Vestido Negro Mujer', 'Vestido de cuerina', 200000, 80000, 15, 'SKU-ROPA-006', 2, 2),
('Sartén Antiadherente 24cm', 'Sartén de aluminio con revestimiento antiadherente', 65000, 30000, 50, 'SKU-HOG-001', 3, 3),
('Licuadora PowerMix 600W', 'Licuadora con vaso de vidrio resistente', 180000, 100000, 35, 'SKU-HOG-002', 3, 3),
('Juego de Sábanas Queen', 'Tela microfibra, color gris claro', 120000, 80000, 40, 'SKU-HOG-003', 3, 3),
('Set de Ollas 5 Piezas', 'Ollas de acero inoxidable con tapas de vidrio', 350000, 200000, 20, 'SKU-HOG-004', 3, 3),
('Aspiradora Compacta', 'Aspiradora portátil con filtro HEPA', 280000, 180000, 18, 'SKU-HOG-005', 3, 3),
('Set de Ollas 3 Piezas', 'Ollas de acero inoxidable con tapas de vidrio', 150000, 85000, 18, 'SKU-HOG-006', 3, 3),
('Balón de Fútbol Profesional', 'Balón oficial tamaño 5, material sintético', 120000, 70000, 30, 'SKU-DEP-001', 4, 4),
('Guantes de Gimnasio', 'Guantes antideslizantes para entrenamiento', 40000, 20000, 45, 'SKU-DEP-002', 4, 4),
('Raqueta de Tenis PowerShot', 'Raqueta liviana de grafito', 350000, 200000, 15, 'SKU-DEP-003', 4, 4),
('Bicicleta Montaña XTR', 'Marco de aluminio, 21 velocidades', 1200000, 800000, 12, 'SKU-DEP-004', 4, 4),
('Colchoneta de Yoga', 'Antideslizante, grosor 10mm', 90000, 45000, 50, 'SKU-DEP-005', 4, 4),
('Balón de Voleibol Profesional', 'Balón oficial tamaño 5, material sintético', 110000, 60000, 35, 'SKU-DEP-006', 4, 4),
('Set de Bloques Creativos', 'Juguetes armables con piezas de plástico resistente', 95000, 50000, 25, 'SKU-JUG-001', 5, 5),
('Muñeca Fashion', 'Muñeca articulada con accesorios', 70000, 35000, 40, 'SKU-JUG-002', 5, 5),
('Carrito de Carrera RC', 'Auto a control remoto con batería recargable', 180000, 100000, 18, 'SKU-JUG-003', 5, 5),
('Rompecabezas 1000 Piezas', 'Diseño de paisaje natural', 60000, 30000, 30, 'SKU-JUG-004', 5, 5),
('Pelota Saltarina', 'Pelota elástica de colores brillantes', 30000, 12000, 45, 'SKU-JUG-005', 5, 5),
('Muñecas Monster High', 'Muñeca articulada con accesorios', 250000, 150000, 60, 'SKU-JUG-006', 5, 5),
('Mouse Gamer RGB', 'Ratón óptico con luces LED personalizables', 130000, 80000, 40, 'SKU-COMP-001', 6, 6),
('Teclado Mecánico Pro', 'Teclado mecánico retroiluminado con switches azules', 220000, 130000, 35, 'SKU-COMP-002', 6, 6),
('Monitor 27" UltraHD', 'Monitor LED 4K con tecnología HDR', 1100000, 850000, 20, 'SKU-COMP-003', 6, 6),
('Disco SSD 1TB', 'Unidad de estado sólido NVMe', 400000, 300000, 50, 'SKU-COMP-004', 6, 6),
('Laptop ProBook 15', 'Portátil i5 con 16GB RAM y SSD 512GB', 2800000, 2000000, 10, 'SKU-COMP-005', 6, 6),
('Mouse LogiTech', 'Ratón Inalámbrico ergonómico', 70000, 20000, 50, 'SKU-COMP-006', 6, 6),
('Shampoo Natural 500ml', 'Producto capilar sin sal ni parabenos', 22000, 12000, 100, 'SKU-BELL-001', 7, 7),
('Crema Hidratante Facial', 'Crema ligera con ácido hialurónico', 45000, 25000, 75, 'SKU-BELL-002', 7, 7),
('Perfume Floral 100ml', 'Fragancia femenina de larga duración', 95000, 60000, 40, 'SKU-BELL-003', 7, 7),
('Secador Ionic Pro', 'Secador de cabello con tecnología iónica', 180000, 100000, 30, 'SKU-BELL-004', 7, 7),
('Plancha Alisadora Ceramic', 'Plancha de cerámica con control de temperatura', 200000, 120000, 25, 'SKU-BELL-005', 7, 7),
('Set de cosmetiqueras', 'Cosmetiquera x3', 100000, 60000, 35, 'SKU-BELL-006', 7, 7),
('Resma de Papel A4', 'Paquete de 500 hojas tamaño carta', 19000, 10000, 75, 'SKU-OFI-001', 8, 8),
('Archivador Metálico', 'Archivador de 4 cajones, color gris', 450000, 300000, 12, 'SKU-OFI-002', 8, 8),
('Silla Ergonómica', 'Silla con soporte lumbar y ruedas giratorias', 600000, 400000, 20, 'SKU-OFI-003', 8, 8),
('Teclado Numérico USB', 'Teclado compacto para oficina', 65000, 35000, 50, 'SKU-OFI-004', 8, 8),
('Silla Gamer', 'Silla con soporte lumbar, ruedas giratorias y luces led', 900000, 500000, 28, 'SKU-OFI-005', 8, 8),
('Lámpara de Escritorio LED', 'Luz blanca regulable con base flexible', 80000, 45000, 35, 'SKU-OFI-006', 8, 8),
('Organizador de Escritorio', 'Organizador multifuncional con compartimientos para útiles', 55000, 30000, 45, 'SKU-OFI-007', 8, 8),
('Marcadores Permanentes x12', 'Set de 12 marcadores de colores surtidos', 38000, 18000, 60, 'SKU-OFI-008', 8, 8);

SELECT * FROM productos;
TRUNCATE TABLE productos;

-- ============================================
-- TABLA: Clientes
-- ============================================

CREATE PROCEDURE InsercionClientes()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE nombres VARCHAR(100);
    DECLARE apellidos VARCHAR(100);
    DECLARE email VARCHAR(150);
    DECLARE contrasena VARCHAR(100);
    DECLARE direccion VARCHAR(255);
    DECLARE ciudades VARCHAR(100);
    DECLARE fecha DATE;

    WHILE i <= 40 DO

        CASE FLOOR(1 + RAND() * 10)
            WHEN 1 THEN SET nombres = 'Carlos';
            WHEN 2 THEN SET nombres = 'María';
            WHEN 3 THEN SET nombres = 'Juan';
            WHEN 4 THEN SET nombres = 'Laura';
            WHEN 5 THEN SET nombres = 'Andrés';
            WHEN 6 THEN SET nombres = 'Paola';
            WHEN 7 THEN SET nombres = 'David';
            WHEN 8 THEN SET nombres = 'Sofía';
            WHEN 9 THEN SET nombres = 'Camila';
            WHEN 10 THEN SET nombres = 'Felipe';
        END CASE;

        CASE FLOOR(1 + RAND() * 10)
            WHEN 1 THEN SET apellidos = 'Ramírez';
            WHEN 2 THEN SET apellidos = 'Pérez';
            WHEN 3 THEN SET apellidos = 'López';
            WHEN 4 THEN SET apellidos = 'Gómez';
            WHEN 5 THEN SET apellidos = 'Torres';
            WHEN 6 THEN SET apellidos = 'Fernández';
            WHEN 7 THEN SET apellidos = 'Morales';
            WHEN 8 THEN SET apellidos = 'Jiménez';
            WHEN 9 THEN SET apellidos = 'Castro';
            WHEN 10 THEN SET apellidos = 'Rodríguez';
        END CASE;

        CASE FLOOR(1 + RAND() * 6)
            WHEN 1 THEN SET ciudades = 'Bogotá';
            WHEN 2 THEN SET ciudades = 'Medellín';
            WHEN 3 THEN SET ciudades = 'Cali';
            WHEN 4 THEN SET ciudades = 'Barranquilla';
            WHEN 5 THEN SET ciudades = 'Bucaramanga';
            WHEN 6 THEN SET ciudades = 'Cartagena';
        END CASE;

        SET email = CONCAT(LOWER(nombres), '.', LOWER(apellidos), i, '@example.com');
        SET contrasena = CONCAT('hash', LPAD(FLOOR(RAND() * 99999), 5, '0'));
        SET direccion = CONCAT('Cra ', FLOOR(RAND() * 100), ' #', FLOOR(RAND() * 100), '-', FLOOR(RAND() * 50), ', ', ciudades);

        -- Fecha de registro aleatoria entre 2024-01-01 y 2025-12-31
        SET fecha = DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 730) DAY);

        INSERT INTO clientes (nombre, apellido, email, contraseña, direccion_envio, fecha_registro)
        VALUES (nombres, apellidos, email, contrasena, direccion, fecha);

        SET i = i + 1;
    END WHILE;
END;

TRUNCATE TABLE clientes;
CALL InsercionClientes();
SELECT * FROM clientes;
DROP PROCEDURE IF EXISTS InsercionClientes;

-- ============================================
-- TABLA: Ventas
-- ============================================
CREATE PROCEDURE InsercionVentas()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE cliente_id INT;
    DECLARE estado_venta VARCHAR(30);
    DECLARE total_venta DECIMAL(10,2);
    DECLARE anio INT;
    DECLARE mes INT;
    DECLARE dia INT;
    DECLARE fecha_venta DATE;

    WHILE i <= 45 DO
        SET cliente_id = FLOOR(1 + RAND() * 40);

        CASE FLOOR(1 + RAND() * 3)
            WHEN 1 THEN SET estado_venta = 'Entregado';
            WHEN 2 THEN SET estado_venta = 'Procesando';
            WHEN 3 THEN SET estado_venta = 'Pendiente de Pago';
        END CASE;

        SET total_venta = 40000 + (RAND() * (2000000 - 40000));

        SET anio = FLOOR(2024 + RAND() * 2);

        SET mes = FLOOR(1 + RAND() * 12);

        SET dia = FLOOR(1 + RAND() * 28);

        SET fecha_venta = MAKEDATE(anio, 1) + INTERVAL (mes - 1) MONTH + INTERVAL (dia - 1) DAY;

        INSERT INTO ventas (id_cliente, estado, total, fecha_venta)
        VALUES (cliente_id, estado_venta, total_venta, fecha_venta);

        SET i = i + 1;
    END WHILE;
END;

TRUNCATE TABLE ventas;
CALL InsercionVentas();
SELECT * FROM ventas;
DROP PROCEDURE IF EXISTS InsercionVentas;

-- ============================================
-- TABLA: Detalle de Ventas
-- ============================================

CREATE PROCEDURE InsercionDetalleVentas()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE venta_id INT;
    DECLARE producto_id INT;
    DECLARE cantidad INT;
    DECLARE precio_unitario DECIMAL(10,2);

    WHILE i <= 90 DO
        SET venta_id = FLOOR(1 + RAND() * 45); -- Debe existir en la tabla ventas
        SET producto_id = FLOOR(1 + RAND() * 50); -- Debe existir en productos
        SET cantidad = FLOOR(1 + RAND() * 10);
        SET precio_unitario = 20000 + (RAND() * (1800000 - 20000));

        INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
        VALUES (venta_id, producto_id, cantidad, precio_unitario);

        SET i = i + 1;
    END WHILE;
END;

DROP PROCEDURE IF EXISTS InsercionDetalleVentas;
TRUNCATE TABLE detalle_ventas;
CALL InsercionDetalleVentas();
SELECT * FROM detalle_ventas;



