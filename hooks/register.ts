import type { EngineInterface, Register } from 'claude-code'

const INTERPRETERS = ['python3', 'python', 'py']

async function runWorkroom($: EngineInterface, args: readonly string[]) {
  const script = `${$.plugin.root}/scripts/workroom.py`
  let failure = 'Python 3 was not found (tried python3, python and py).'
  for (const interpreter of INTERPRETERS) {
    const result = await $.process.run([interpreter, script, ...args]).catch(() => undefined)
    if (!result) continue
    if (result.exitCode === 0) return result.stdout.trimEnd()
    failure = result.stderr.trim() || `${interpreter} exited with ${result.exitCode}`
  }
  return `workroom: ${failure}`
}

async function answer($: EngineInterface, command: string, args: readonly string[]) {
  const text = await runWorkroom($, args)
  return { text, context: [`/${command} output:\n${text}`] }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'rooms', description: 'List your workrooms (instant, no model)' })
    await $.command.register({ name: 'room', description: 'Say which workroom you are in (instant, no model)' })
    return next(e)
  })

  on('command.run', { command: 'rooms' }, $ => answer($, 'rooms', ['list', '--text']))
  on('command.run', { command: 'room' }, $ => answer($, 'room', ['list', '--text', '--current']))
}
