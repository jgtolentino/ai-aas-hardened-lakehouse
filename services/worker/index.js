const fastify = require('fastify')({ logger: true })

// Health check route
fastify.get('/health', async (request, reply) => {
  return { status: 'healthy', service: 'worker' }
})

// Root route
fastify.get('/', async (request, reply) => {
  return { message: 'AI-AAS Hardened Lakehouse Worker Service' }
})

// Start server
const start = async () => {
  try {
    await fastify.listen({ port: 3000, host: '0.0.0.0' })
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

start()