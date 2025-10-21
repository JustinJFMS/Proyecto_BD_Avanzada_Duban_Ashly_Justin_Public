CREATE DATABASE IF NOT EXISTS Ecommerce;
USE Ecommerce;
DROP DATABASE IF EXISTS Ecommerce;

CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    contraseña VARCHAR(255) NOT NULL,
    direccion_envio TEXT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS auditoria_clientes (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_antiguo VARCHAR (50) NOT NULL,
    valor_nuevo VARCHAR (50) NOT NULL,
    fecha_modificacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Crearemos el trigger que estara a la espera de cualquier modificacion en elos campos email y direccion_envio
DROP TRIGGER IF EXISTS trg_audit_cliente_after_update;

-- creacion del trigger
CREATE TRIGGER trg_audit_cliente_after_update
AFTER INSERT ON clientes
-- insertamos valores en la tabla auditoria 
FOR EACH ROW 
BEGIN 
	-- comparamos el valor viejo con el nuevo
	 IF OLD.email <> NEW.email THEN
        INSERT INTO auditoria_clientes (campo_modificado, valor_antiguo, valor_nuevo)
        -- insertamos valores
        VALUES ('Email', OLD.email, NEW.email);
       -- comparamos el valor viejo con el nuevo
     ELSEIF OLD.direccion_envio <> NEW.direccion_envio THEN
        -- insertamos valores
     	INSERT INTO auditoria_clientes (campo_modificado, valor_antiguo, valor_nuevo)
        VALUES ('Direccion', OLD.direccion_envio, NEW.direccion_envio);
     END IF;
END;

SELECT id_cliente, email, direccion_envio FROM clientes WHERE id_cliente = 1;
UPDATE clientes SET email = 'esunaprueb@gmail.com' WHERE id_cliente = 1;
SELECT * FROM auditoria_clientes ORDER BY id_auditoria DESC;
