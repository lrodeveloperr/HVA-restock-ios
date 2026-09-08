# Política de privacidad de Control remoto de TV

**Fecha de entrada en vigor: 8 de septiembre de 2026**

Control remoto de TV no envía datos personales a WorksBien Studios Inc. La app no tiene cuentas operadas por el desarrollador, publicidad, análisis, rastreo ni servicio en la nube.

## Red local

La app usa la red local para buscar una televisión compatible y comunicarse directamente con ella. Las respuestas de detección son datos de red no confiables. El usuario selecciona una TV y completa el proceso con el PIN que aparece en la pantalla antes de controlarla. Los comandos y el texto escrito viajan del dispositivo Apple a la TV seleccionada; WorksBien Studios no los recibe. El software del fabricante procesa ese tráfico conforme a sus propias prácticas.

Durante el primer emparejamiento, las TV compatibles presentan un certificado local autofirmado que no puede verificarse mediante una autoridad de certificación pública para la dirección privada de la TV. La app confía temporalmente solo en el punto final privado seleccionado para intercambiar el PIN mostrado en la TV y guarda esa identidad del certificado después de que el PIN se acepta. Esto protege la continuidad de conexiones posteriores, pero no puede demostrar de forma independiente la identidad de la TV frente a un atacante activo durante el primer emparejamiento. Empareja solo en una red privada de confianza.

## Datos guardados en el dispositivo

La dirección IPv4 privada, el puerto y el nombre de la TV seleccionada, el token de vinculación emitido por la TV y la identidad de su certificado se guardan en el llavero de iOS como elementos exclusivos del dispositivo. El UUID de cliente generado por la app y la preferencia de respuesta háptica se guardan en las preferencias locales. **Olvidar esta TV** solicita eliminar la dirección, el token y la identidad de una TV. **Eliminar todos los datos guardados de TV** solicita eliminar todas las direcciones, tokens, identidades de certificado y el UUID de cliente de TV generado por la app. También hay una opción separada para restablecer la identidad si cambia el certificado de la TV.

## Compras

Apple procesa la prueba gratis de 1 día y el desbloqueo completo opcional de pago único. La app consulta en StoreKit el identificador y tipo de producto verificados, la fecha de compra, el estado vigente de derecho o revocación y el precio localizado para decidir si el control está disponible. La prueba dura 24 horas, no se renueva y no genera cargos automáticos. El desarrollador no recibe datos de tarjetas de pago.

## Uso compartido y conservación

WorksBien Studios no recibe, vende ni comparte los datos locales descritos. Estos permanecen en el dispositivo hasta que el usuario usa los controles de eliminación, iOS borra el almacenamiento correspondiente o se borra el dispositivo. Apple y el fabricante de la TV pueden procesar datos por separado como parte de sus servicios o dispositivos.

## Menores

La app no está diseñada para recopilar información de menores y no envía deliberadamente información del usuario a WorksBien Studios.

## Cambios y contacto

Los cambios importantes se indicarán mediante la actualización de esta política y su fecha de entrada en vigor.

WorksBien Studios Inc.  
`https://worksbienstudios.com/customerservice`

Control remoto de TV es una app independiente, no afiliada ni respaldada por Vizio, Inc.
