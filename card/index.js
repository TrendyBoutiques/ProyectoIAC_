const AWS = require('aws-sdk');
const dynamoDb = new AWS.DynamoDB.DocumentClient();
const winston = require('winston');

const CART_TABLE = process.env.CART_TABLE;
const USERS_TABLE = process.env.USERS_TABLE;

// Configuración del logger con Winston
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

exports.handler = async (event) => {
  logger.info("Evento recibido", { event });

  const action = event.action;

  switch (action) {
    case 'add':
      return await addToCart(event);
    case 'remove':
      return await removeFromCart(event);
    case 'get':
      return await getCart(event);
    default:
      logger.warn("Acción no válida", { action });
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Acción no válida' }),
      };
  }
};

async function addToCart(event) {
  const { userId, productId, quantity, price } = event;

  if (!userId || !productId || !quantity || !price) {
    logger.error("Parámetros faltantes para agregar producto", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  const getParams = {
    TableName: CART_TABLE,
    Key: { userId },
  };

  try {
    const result = await dynamoDb.get(getParams).promise();
    let cart = result.Item ? result.Item.cart : [];

    const productIndex = cart.findIndex(item => item.productId === productId);
    if (productIndex !== -1) {
      cart[productIndex].quantity += quantity;
      logger.info("Cantidad actualizada en el carrito", { userId, productId, quantity });
    } else {
      cart.push({ productId, quantity, price });
      logger.info("Producto agregado al carrito", { userId, productId });
    }

    const putParams = {
      TableName: CART_TABLE,
      Item: { userId, cart },
    };

    await dynamoDb.put(putParams).promise();

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Producto agregado al carrito', cart }),
    };
  } catch (error) {
    logger.error("Error al agregar producto al carrito", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al agregar producto al carrito' }),
    };
  }
}

async function removeFromCart(event) {
  const { userId, productId } = event;

  if (!userId || !productId) {
    logger.error("Parámetros faltantes para eliminar producto", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  const getParams = {
    TableName: CART_TABLE,
    Key: { userId },
  };

  try {
    const result = await dynamoDb.get(getParams).promise();
    let cart = result.Item ? result.Item.cart : [];

    const productIndex = cart.findIndex(item => item.productId === productId);
    if (productIndex === -1) {
      logger.warn("Producto no encontrado en el carrito", { userId, productId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Producto no encontrado en el carrito' }),
      };
    }

    cart.splice(productIndex, 1);
    logger.info("Producto eliminado del carrito", { userId, productId });

    const putParams = {
      TableName: CART_TABLE,
      Item: { userId, cart },
    };

    await dynamoDb.put(putParams).promise();

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Producto eliminado del carrito', cart }),
    };
  } catch (error) {
    logger.error("Error al eliminar producto del carrito", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al eliminar producto del carrito' }),
    };
  }
}

async function getCart(event) {
  const { userId } = event;

  if (!userId) {
    logger.error("Falta el parámetro userId", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro userId' }),
    };
  }

  const getParams = {
    TableName: CART_TABLE,
    Key: { userId },
  };

  try {
    const result = await dynamoDb.get(getParams).promise();

    if (!result.Item) {
      logger.warn("Carrito no encontrado", { userId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Carrito no encontrado' }),
      };
    }

    logger.info("Carrito obtenido exitosamente", { userId });
    return {
      statusCode: 200,
      body: JSON.stringify(result.Item.cart),
    };
  } catch (error) {
    logger.error("Error al obtener el carrito", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al obtener el carrito' }),
    };
  }
}
