const AWS = require('aws-sdk');
const dynamoDb = new AWS.DynamoDB.DocumentClient();
const ses = new AWS.SES();
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

// Nombre de las tablas de DynamoDB y otros recursos
const ORDERS_TABLE = process.env.ORDERS_TABLE;
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;

exports.handler = async (event) => {
  logger.info("Evento recibido", { event });

  const action = event.action;  // Acción que determinará el comportamiento (crear, obtener, actualizar, etc.)

  switch (action) {
    case 'createOrder':
      return await createOrder(event);
    case 'updateOrder':
      return await updateOrder(event);
    case 'getOrder':
      return await getOrder(event);
    case 'listOrders':
      return await listOrders(event);
    case 'sendOrderConfirmation':
      return await sendOrderConfirmation(event);
    default:
      logger.warn("Acción no válida", { action });
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Acción no válida' }),
      };
  }
};

// Crear una nueva orden
async function createOrder(event) {
  const { orderId, customerId, items, totalAmount, status, shippingAddress, email } = event;

  if (!orderId || !customerId || !items || !totalAmount || !status || !shippingAddress) {
    logger.error("Parámetros faltantes al crear la orden", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  // Crear el objeto de la orden
  const order = {
    orderId,
    customerId,
    items,
    totalAmount,
    status,
    shippingAddress,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  // Guardar la orden en DynamoDB
  const params = {
    TableName: ORDERS_TABLE,
    Item: order,
  };

  try {
    await dynamoDb.put(params).promise();
    logger.info("Orden creada exitosamente", { orderId });
    
    // Enviar correo de confirmación (opcional)
    await sendOrderConfirmation({ orderId, email });

    return {
      statusCode: 201,
      body: JSON.stringify({ message: 'Orden creada exitosamente', orderId }),
    };
  } catch (error) {
    logger.error("Error al crear la orden", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al crear la orden' }),
    };
  }
}

// Actualizar una orden existente
async function updateOrder(event) {
  const { orderId, status, shippingAddress } = event;

  if (!orderId) {
    logger.error("Faltan parámetros al actualizar la orden", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  // Obtener la orden actual
  const getParams = {
    TableName: ORDERS_TABLE,
    Key: { orderId }
  };

  try {
    const result = await dynamoDb.get(getParams).promise();
    if (!result.Item) {
      logger.warn("Orden no encontrada para actualizar", { orderId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Orden no encontrada' }),
      };
    }

    // Preparar la actualización de la orden
    const updateParams = {
      TableName: ORDERS_TABLE,
      Key: { orderId },
      UpdateExpression: 'SET #status = :status, #shippingAddress = :shippingAddress, #updatedAt = :updatedAt',
      ExpressionAttributeNames: {
        '#status': 'status',
        '#shippingAddress': 'shippingAddress',
        '#updatedAt': 'updatedAt'
      },
      ExpressionAttributeValues: {
        ':status': status || result.Item.status,
        ':shippingAddress': shippingAddress || result.Item.shippingAddress,
        ':updatedAt': new Date().toISOString(),
      },
      ReturnValues: "ALL_NEW"
    };

    const updatedResult = await dynamoDb.update(updateParams).promise();
    logger.info("Orden actualizada exitosamente", { orderId });
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Orden actualizada exitosamente', updatedOrder: updatedResult.Attributes }),
    };
  } catch (error) {
    logger.error("Error al actualizar la orden", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al actualizar la orden' }),
    };
  }
}

// Obtener una orden por su ID
async function getOrder(event) {
  const { orderId } = event;

  if (!orderId) {
    logger.error("Falta el parámetro orderId", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro orderId' }),
    };
  }

  const params = {
    TableName: ORDERS_TABLE,
    Key: { orderId }
  };

  try {
    const result = await dynamoDb.get(params).promise();
    if (!result.Item) {
      logger.warn("Orden no encontrada", { orderId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Orden no encontrada' }),
      };
    }

    logger.info("Orden obtenida exitosamente", { orderId });
    return {
      statusCode: 200,
      body: JSON.stringify(result.Item),
    };
  } catch (error) {
    logger.error("Error al obtener la orden", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al obtener la orden' }),
    };
  }
}

// Listar todas las órdenes
async function listOrders(event) {
  const params = {
    TableName: ORDERS_TABLE,
  };

  try {
    const result = await dynamoDb.scan(params).promise();
    logger.info("Órdenes listadas exitosamente");
    return {
      statusCode: 200,
      body: JSON.stringify(result.Items),
    };
  } catch (error) {
    logger.error("Error al listar las órdenes", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al listar las órdenes' }),
    };
  }
}

// Enviar confirmación de pedido por correo electrónico usando SES
async function sendOrderConfirmation(event) {
  const { orderId, email } = event;

  if (!email || !orderId) {
    logger.error("Faltan parámetros para enviar la confirmación del pedido", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios para enviar correo' }),
    };
  }

  const params = {
    Destination: {
      ToAddresses: [email],
    },
    Message: {
      Body: {
        Text: {
          Data: `¡Gracias por tu compra! Tu pedido con ID ${orderId} ha sido recibido y está siendo procesado.`,
        },
      },
      Subject: {
        Data: 'Confirmación de Pedido',
      },
    },
    Source: 'no-reply@tu-ecommerce.com',  // Cambia esto por tu correo de SES verificado
  };

  try {
    await ses.sendEmail(params).promise();
    logger.info("Correo de confirmación enviado exitosamente", { orderId, email });
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Confirmación de pedido enviada' }),
    };
  } catch (error) {
    logger.error("Error al enviar confirmación de pedido", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al enviar confirmación de pedido' }),
    };
  }
}
