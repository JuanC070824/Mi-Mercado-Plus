const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../web/mercadopago.js'), 'utf8');

function entorno() {
  const origin = 'http://localhost:3000', messages = [], listeners = {}, nodes = {};
  const element = id => nodes[id] ??= {hidden: false, value: '', listeners: {},
    classList: {toggle() {}}, setAttribute() {}, addEventListener(type, cb) {this.listeners[type] = cb;}};
  let settings;
  const parent = {postMessage(data, target) {assert.equal(target, origin);messages.push(JSON.parse(data));}};
  const sdk = {bricks: () => ({create: async (_, __, config) => {settings = config;return {unmount() {}};}}),
    yape: () => ({create: async () => ({id: 'token_yape_ficticio'})})};
  const context = {location: {hash: '#nonce-ficticio', origin}, parent,
    document: {getElementById: element, querySelector: element,
      querySelectorAll: () => [], body: {getBoundingClientRect: () => ({height: 700})}},
    window: {addEventListener: (name, callback) => listeners[name] = callback,
      MercadoPago: function() {return sdk;}},
    ResizeObserver: class {observe() {}}, MercadoPago: function() {return sdk;}};
  vm.runInNewContext(script, context);
  const enviar = (data, extra = {}) => listeners.message({origin, source: parent,
    data: JSON.stringify({channel: 'mmp-payment', session: 'nonce-ficticio', ...data}), ...extra});
  return {messages, element, enviar, parent, get settings() {return settings;}};
}

test('rechaza configuración de otra ventana, otro origen o una sesión antigua', async () => {
  const env = entorno();
  const setup = {type: 'init', publicKey: 'publica-ficticia', amount: 24};
  env.enviar(setup, {origin: 'https://otro.test'});
  env.enviar(setup, {source: {}});
  env.enviar({...setup, session: 'sesion-anterior'});
  await Promise.resolve();assert.equal(env.settings, undefined);
  env.enviar(setup);await Promise.resolve();assert.ok(env.settings);
});

test('solo envía el token y datos permitidos; una respuesta ajena no confirma el pago', async () => {
  const env = entorno();
  env.enviar({type: 'init', publicKey: 'publica-ficticia', amount: 24});await Promise.resolve();
  const result = env.settings.callbacks.onSubmit({token: 'token_ficticio', payment_method_id: 'master',
    installments: 1, transaction_amount: .01, security_code: 'NO_ENVIAR', card_number: 'NO_ENVIAR',
    payer: {email: 'test@example.test', identification: {type: 'DNI', number: '12345678'}}}, {paymentTypeId: 'credit_card'});
  const request = env.messages.find(m => m.type === 'submit');
  assert.ok(request);
  assert.equal(request.payload.token, 'token_ficticio');
  assert.equal(request.payload.transaction_amount, undefined);
  assert.ok(!JSON.stringify(request).includes('NO_ENVIAR'));
  env.enviar({type: 'result', approved: true}, {origin: 'https://otro.test'});
  assert.equal(env.element('tarjeta').hidden, false);
  env.enviar({type: 'result', approved: true});await result;
  assert.equal(env.element('tarjeta').hidden, true);
});

test('Yape borra el código y no lo envía a Flutter ni al backend', async () => {
  const env = entorno();
  env.enviar({type: 'init', publicKey: 'publica-ficticia', amount: 24});await Promise.resolve();
  env.element('codigo').value = '123456';env.element('celular').value = '900000001';
  env.element('correo').value = 'test@example.test';
  const pago = env.element('yape').listeners.submit({preventDefault() {}});
  await new Promise(resolve => setImmediate(resolve));
  const request = env.messages.find(m => m.type === 'submit');
  assert.equal(env.element('codigo').value, '');
  assert.equal(request.payload.token, 'token_yape_ficticio');
  assert.ok(!JSON.stringify(request).includes('123456'));
  env.enviar({type: 'result', approved: true});await pago;
});
