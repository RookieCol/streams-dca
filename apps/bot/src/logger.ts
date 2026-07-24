type LogFields = Record<string, unknown>;

function line(level: string, msg: string, fields?: LogFields) {
  const entry = { ts: new Date().toISOString(), level, msg, ...fields };
  console.log(JSON.stringify(entry));
}

export const logger = {
  info: (msg: string, fields?: LogFields) => line("info", msg, fields),
  warn: (msg: string, fields?: LogFields) => line("warn", msg, fields),
  error: (msg: string, fields?: LogFields) => line("error", msg, fields),
};
