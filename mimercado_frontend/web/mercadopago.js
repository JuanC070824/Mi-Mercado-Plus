/* Only tokenized data crosses into Flutter. PAN/CVV stay in provider fields.
   This document receives neither a session token nor an Access Token. */
(() => {
  'use strict';
  const session = location.hash.slice(1), origin = location.origin;
  const status = document.getElementById('estado');
  let mp, brick, resolvePayment, rejectPayment, started = false, busy = false;
  const send = (type, extra = {}) => parent.postMessage(JSON.stringify({channel: 'mmp-payment', session, type, ...extra}), origin);
  const message = (text, error = false) => {status.textContent = text;status.classList.toggle('error', error);};
  const setBusy = value => {
    busy = value;
    document.querySelectorAll('nav button, #yape button').forEach(button => button.disabled = value);
  };
  const submit = payload => new Promise((resolve, reject) => {
    if (busy) {reject(new Error('Espera el resultado del pago.'));return;}
    setBusy(true);resolvePayment = resolve;rejectPayment = reject;
    message('Procesando tu pago. No cierres esta pantalla.');send('submit', {payload});
  });
  async function start(config) {
    if (started) return;started = true;
    try {
      if (!window.MercadoPago) throw new Error('SDK no disponible');
      mp = new MercadoPago(config.publicKey, {locale: 'es-PE'});
      brick = await mp.bricks().create('cardPayment', 'card-payment', {
        initialization: {amount: config.amount},
        customization: {visual: {style: {theme: 'default'}}, paymentMethods: {maxInstallments: 1}},
        callbacks: {
          onReady: () => {message('Ingresa únicamente datos y tarjetas de prueba.');send('ready');},
          onSubmit: (form, extra) => {
            const payload = {token: form.token, payment_method_id: form.payment_method_id,
              payment_type_id: extra.paymentTypeId, installments: Number(form.installments || 1), email: form.payer.email};
            if (form.payer.identification?.type && form.payer.identification?.number) {
              payload.identification_type = form.payer.identification.type;
              payload.identification_number = form.payer.identification.number;
            }
            return submit(payload);
          },
          onError: () => {if (!busy) message('Revisa los campos del formulario o vuelve a cargarlo.', true);}
        }
      });
    } catch (_) {message('No pudimos cargar el formulario de Mercado Pago. Vuelve a cargarlo y revisa la conexión.', true);send('error');}
  }
  window.addEventListener('message', event => {
    if (event.origin !== origin || event.source !== parent || typeof event.data !== 'string') return;
    let data;try {data = JSON.parse(event.data);} catch (_) {return;}
    if (data.channel !== 'mmp-payment' || data.session !== session) return;
    if (data.type === 'init') start(data);
    if (data.type === 'result') {
      const approved = data.approved === true;
      message(data.message || (approved ? 'Pago confirmado.' : 'Consulta el estado antes de volver a pagar.'), !approved);
      if (approved) {document.querySelector('nav').hidden = true;document.getElementById('tarjeta').hidden = true;document.getElementById('yape').hidden = true;}
      else if (data.retry === true) setBusy(false);
      const resolve = resolvePayment, reject = rejectPayment;
      resolvePayment = rejectPayment = null;
      if (approved) resolve?.(); else reject?.(new Error('Pago no aprobado'));
      document.getElementById('codigo').value = '';
    }
    if (data.type === 'dispose') brick?.unmount();
  });
  for (const name of ['tarjeta', 'yape']) {
    document.getElementById(name + '-tab').addEventListener('click', () => {
      if (busy) return;
      for (const option of ['tarjeta', 'yape']) {
        document.getElementById(option).hidden = option !== name;
        document.getElementById(option + '-tab').setAttribute('aria-selected', String(option === name));
      }
    });
  }
  document.getElementById('yape').addEventListener('submit', async event => {
    event.preventDefault();if (busy || !mp) return;
    let submitted = false;
    setBusy(true);
    try {
      const phone = document.getElementById('celular').value.trim();
      const token = await mp.yape({otp: document.getElementById('codigo').value, phoneNumber: phone}).create();
      document.getElementById('codigo').value = '';setBusy(false);submitted = true;
      await submit({token: token.id, payment_method_id: 'yape', payment_type_id: 'debit_card', installments: 1,
                    email: document.getElementById('correo').value.trim(), phone});
    } catch (_) {if (!submitted) {setBusy(false);message('No se pudo validar Yape. Revisa el celular y el código.', true);}}
  });
  window.addEventListener('pagehide', () => brick?.unmount());send('loaded');
})();
