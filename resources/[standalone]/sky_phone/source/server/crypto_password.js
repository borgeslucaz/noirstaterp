'use strict'

const { randomBytes, randomInt, scryptSync, timingSafeEqual } = require('node:crypto')

const KEY_LENGTH = 32
const SCRYPT_COST = 32768
const SCRYPT_BLOCK_SIZE = 8
const SCRYPT_PARALLELISM = 1
const MAX_MEMORY = 64 * 1024 * 1024

exports('CryptoHashPassword', (password) => {
  if (typeof password !== 'string' || password.length < 8 || password.length > 72) return null

  const salt = randomBytes(16)
  const hash = scryptSync(password, salt, KEY_LENGTH, {
    N: SCRYPT_COST,
    maxmem: MAX_MEMORY,
    p: SCRYPT_PARALLELISM,
    r: SCRYPT_BLOCK_SIZE,
  })
  return [
    'scrypt', 'v=1', `N=${SCRYPT_COST}`, `r=${SCRYPT_BLOCK_SIZE}`,
    `p=${SCRYPT_PARALLELISM}`, salt.toString('base64'), hash.toString('base64'),
  ].join('$')
})

exports('CryptoVerifyPassword', (password, encoded) => {
  if (typeof password !== 'string' || typeof encoded !== 'string') return false

  const parts = encoded.split('$')
  if (
    parts.length !== 7 || parts[0] !== 'scrypt' || parts[1] !== 'v=1' ||
    parts[2] !== `N=${SCRYPT_COST}` || parts[3] !== `r=${SCRYPT_BLOCK_SIZE}` ||
    parts[4] !== `p=${SCRYPT_PARALLELISM}`
  ) return false

  try {
    const salt = Buffer.from(parts[5], 'base64')
    const expected = Buffer.from(parts[6], 'base64')
    if (salt.length !== 16 || expected.length !== KEY_LENGTH) return false
    const actual = scryptSync(password, salt, KEY_LENGTH, {
      N: SCRYPT_COST,
      maxmem: MAX_MEMORY,
      p: SCRYPT_PARALLELISM,
      r: SCRYPT_BLOCK_SIZE,
    })
    return timingSafeEqual(actual, expected)
  } catch {
    return false
  }
})

exports('CryptoRandomInt', (minimum, maximum) => {
  if (!Number.isSafeInteger(minimum) || !Number.isSafeInteger(maximum) || minimum >= maximum) {
    return null
  }
  return randomInt(minimum, maximum)
})
