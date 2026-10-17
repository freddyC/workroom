import { expect, test } from 'claude-code/testing'

test('/rooms and /room answer from the script without the model', async ($, on) => {
  const calls: string[][] = []
  on('process.run', async (_, e) => {
    calls.push([...e.argv])
    const isCurrent = e.argv.includes('--current')
    return { value: { exitCode: 0, stdout: isCurrent ? "You're in workroom-abc\n" : 'Active workrooms (1) in /work:\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  const rooms = await $.command.run({ command: 'rooms' })
  expect(rooms.text).toBe('Active workrooms (1) in /work:')
  expect(rooms.context?.[0]).toContain('/rooms output:')

  const room = await $.command.run({ command: 'room' })
  expect(room.text).toBe("You're in workroom-abc")

  expect(calls[0]?.[0]).toBe('python3')
  expect(calls[0]?.slice(-2)).toEqual(['list', '--text'])
  expect(calls[1]?.slice(-3)).toEqual(['list', '--text', '--current'])
})

test('falls back to python when python3 is missing', async ($, on) => {
  const tried: string[] = []
  on('process.run', async (_, e) => {
    tried.push(e.argv[0] ?? '')
    if (e.argv[0] === 'python3') return { deny: 'python3: command not found' }
    return { value: { exitCode: 0, stdout: 'ok\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  const rooms = await $.command.run({ command: 'rooms' })
  expect(rooms.text).toBe('ok')
  expect(tried).toEqual(['python3', 'python'])
})
