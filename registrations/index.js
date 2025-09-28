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

// Nombre de la tabla de DynamoDB para usuarios
const USERS_TABLE = process.env.USERS_TABLE;

exports.handler = async (event) => {
  logger.info("Evento recibido", { event });

  const action = event.action;  // Acción que determinará el comportamiento (crear, obtener, actualizar, etc.)

  switch (action) {
    case 'registerUser':
      return await registerUser(event);
    case 'getUser':
      return await getUser(event);
    case 'updateUser':
      return await updateUser(event);
    case 'listUsers':
      return await listUsers(event);
    default:
      logger.warn("Acción no válida", { action });
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Acción no válida' }),
      };
  }
};

// Registrar un nuevo usuario
async function registerUser(event) {
  const { userId, name, email, password } = event;

  if (!userId || !name || !email || !password) {
    logger.error("Parámetros faltantes al registrar el usuario", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Faltan parámetros necesarios' }),
    };
  }

  // Crear el objeto de usuario
  const user = {
    userId,
    name,
    email,
    password,  // En un entorno real, no guardarías contraseñas en texto plano
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  // Guardar el usuario en DynamoDB
  const params = {
    TableName: USERS_TABLE,
    Item: user,
  };

  try {
    await dynamoDb.put(params).promise();
    logger.info("Usuario registrado exitosamente", { userId });
    return {
      statusCode: 201,
      body: JSON.stringify({ message: 'Usuario registrado exitosamente', userId }),
    };
  } catch (error) {
    logger.error("Error al registrar el usuario", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al registrar el usuario' }),
    };
  }
}

// Obtener información de un usuario por su ID
async function getUser(event) {
  const { userId } = event;

  if (!userId) {
    logger.error("Falta el parámetro userId", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro userId' }),
    };
  }

  const params = {
    TableName: USERS_TABLE,
    Key: { userId }
  };

  try {
    const result = await dynamoDb.get(params).promise();
    if (!result.Item) {
      logger.warn("Usuario no encontrado", { userId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Usuario no encontrado' }),
      };
    }

    logger.info("Usuario obtenido exitosamente", { userId });
    return {
      statusCode: 200,
      body: JSON.stringify(result.Item),
    };
  } catch (error) {
    logger.error("Error al obtener el usuario", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al obtener el usuario' }),
    };
  }
}

// Actualizar la información de un usuario
async function updateUser(event) {
  const { userId, name, email, password } = event;

  if (!userId) {
    logger.error("Falta el parámetro userId", { event });
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Falta el parámetro userId' }),
    };
  }

  // Obtener el usuario actual
  const getParams = {
    TableName: USERS_TABLE,
    Key: { userId }
  };

  try {
    const result = await dynamoDb.get(getParams).promise();
    if (!result.Item) {
      logger.warn("Usuario no encontrado para actualizar", { userId });
      return {
        statusCode: 404,
        body: JSON.stringify({ message: 'Usuario no encontrado' }),
      };
    }

    // Preparar la actualización del usuario
    const updateParams = {
      TableName: USERS_TABLE,
      Key: { userId },
      UpdateExpression: 'SET #name = :name, #email = :email, #password = :password, #updatedAt = :updatedAt',
      ExpressionAttributeNames: {
        '#name': 'name',
        '#email': 'email',
        '#password': 'password',
        '#updatedAt': 'updatedAt',
      },
      ExpressionAttributeValues: {
        ':name': name || result.Item.name,
        ':email': email || result.Item.email,
        ':password': password || result.Item.password,
        ':updatedAt': new Date().toISOString(),
      },
      ReturnValues: "ALL_NEW"
    };

    const updatedResult = await dynamoDb.update(updateParams).promise();
    logger.info("Usuario actualizado exitosamente", { userId });
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Usuario actualizado exitosamente', updatedUser: updatedResult.Attributes }),
    };
  } catch (error) {
    logger.error("Error al actualizar el usuario", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al actualizar el usuario' }),
    };
  }
}

// Listar todos los usuarios
async function listUsers(event) {
  const params = {
    TableName: USERS_TABLE,
  };

  try {
    const result = await dynamoDb.scan(params).promise();
    logger.info("Usuarios listados exitosamente");
    return {
      statusCode: 200,
      body: JSON.stringify(result.Items),
    };
  } catch (error) {
    logger.error("Error al listar los usuarios", { error });
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error al listar los usuarios' }),
    };
  }
}
