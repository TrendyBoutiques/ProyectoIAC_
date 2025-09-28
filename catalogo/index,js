const AWS = require('aws-sdk');
const dynamoDb = new AWS.DynamoDB.DocumentClient();
const winston = require('winston');

// Configuración de Winston (Logging)
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ],
});

// Nombre de la tabla de DynamoDB desde las variables de entorno
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;

exports.handler = async (event) => {
  logger.info("Evento recibido", { event });

  // Obtener la acción desde el evento
  const action = event.action;

  switch (action) {
    case 'create':
      return await createProduct(event);
    case 'update':
      return await updateProduct(event);
    case 'get':
      return await getProduct(event);
    case 'list':
      return await listProducts(event);
    case 'delete':
      return await deleteProduct(event);
    default:
      logger.warn("Acción no válida", { action });
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Acción no válida' }),
      };
  }
};

// Crear un nuevo producto
async function createProduct(event) {
  const { productId, name, description, price, size, color, stock } = event;

  if (!productId || !name || !price || !stock) {
    logger.error("Parámetros faltantes al crear producto", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  const params = {
    TableName: PRODUCTS_TABLE,
    Item: {
      productId,
      name,
      description,
      price,
      size,
      color,
      stock,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
  };

  try {
    await dynamoDb.put(params).promise();
    logger.info("Producto creado exitosamente", { productId });
    return {
      statusCode: 201,
      body: JSON.stringify({ message: 'Producto creado exitosamente' }),
    };
  } catch (error) {
    logger.error("Error al crear producto", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al crear producto' }),
    };
  }
}

// Actualizar un producto existente
async function updateProduct(event) {
  const { productId, name, description, price, size, color, stock } = event;

  if (!productId) {
    logger.error("Faltan parámetros al actualizar producto", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  // Obtener producto actual
  const getParams = {
    TableName: PRODUCTS_TABLE,
    Key: { productId }
  };

  try {
    const result = await dynamoDb.get(getParams).promise();
    if (!result.Item) {
      logger.warn("Producto no encontrado para actualización", { productId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Producto no encontrado' }),
      };
    }

    // Preparar actualización
    const updateParams = {
      TableName: PRODUCTS_TABLE,
      Key: { productId },
      UpdateExpression: 'SET #name = :name, #description = :description, #price = :price, #size = :size, #color = :color, #stock = :stock, #updatedAt = :updatedAt',
      ExpressionAttributeNames: {
        '#name': 'name',
        '#description': 'description',
        '#price': 'price',
        '#size': 'size',
        '#color': 'color',
        '#stock': 'stock',
        '#updatedAt': 'updatedAt'
      },
      ExpressionAttributeValues: {
        ':name': name || result.Item.name,
        ':description': description || result.Item.description,
        ':price': price || result.Item.price,
        ':size': size || result.Item.size,
        ':color': color || result.Item.color,
        ':stock': stock || result.Item.stock,
        ':updatedAt': new Date().toISOString()
      },
      ReturnValues: "ALL_NEW"
    };

    const updatedResult = await dynamoDb.update(updateParams).promise();
    logger.info("Producto actualizado exitosamente", { productId });
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Producto actualizado exitosamente', updatedProduct: updatedResult.Attributes }),
    };
  } catch (error) {
    logger.error("Error al actualizar producto", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al actualizar producto' }),
    };
  }
}

// Obtener un producto por su ID
async function getProduct(event) {
  const { productId } = event;

  if (!productId) {
    logger.error("Falta el parámetro productId", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro productId' }),
    };
  }

  const params = {
    TableName: PRODUCTS_TABLE,
    Key: { productId }
  };

  try {
    const result = await dynamoDb.get(params).promise();
    if (!result.Item) {
      logger.warn("Producto no encontrado", { productId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Producto no encontrado' }),
      };
    }

    logger.info("Producto obtenido exitosamente", { productId });
    return {
      statusCode: 200,
      body: JSON.stringify(result.Item),
    };
  } catch (error) {
    logger.error("Error al obtener producto", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al obtener producto' }),
    };
  }
}

// Listar todos los productos
async function listProducts(event) {
  const params = {
    TableName: PRODUCTS_TABLE,
  };

  try {
    const result = await dynamoDb.scan(params).promise();
    logger.info("Productos listados exitosamente");
    return {
      statusCode: 200,
      body: JSON.stringify(result.Items),
    };
  } catch (error) {
    logger.error("Error al listar productos", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al listar productos' }),
    };
  }
}

// Eliminar un producto por su ID
async function deleteProduct(event) {
  const { productId } = event;

  if (!productId) {
    logger.error("Falta el parámetro productId para eliminar producto", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro productId' }),
    };
  }

  const params = {
    TableName: PRODUCTS_TABLE,
    Key: { productId }
  };

  try {
    await dynamoDb.delete(params).promise();
    logger.info("Producto eliminado exitosamente", { productId });
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Producto eliminado exitosamente' }),
    };
  } catch (error) {
    logger.error("Error al eliminar producto", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al eliminar producto' }),
    };
  }
}
