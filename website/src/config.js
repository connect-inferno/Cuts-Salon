// Everything a non-developer might need to change on the site lives here.

// Same number and email the app itself uses (mobile/lib/data/support_contact.dart).
export const WHATSAPP_NUMBER = '917972394120'; // country code + number, digits only
export const PHONE_DISPLAY = '+91 79723 94120';
export const SUPPORT_EMAIL = 'connect.infernos@gmail.com';

export const WHATSAPP_MESSAGE =
  "Hi! I'd like to know more about Stylux for my salon.";

export const whatsappLink = (message = WHATSAPP_MESSAGE) =>
  `https://wa.me/${WHATSAPP_NUMBER}?text=${encodeURIComponent(message)}`;

// The studio that builds Stylux. An empty URL shows the credit as plain
// text instead of a link.
export const DEVELOPER_NAME = 'Infernos';
export const DEVELOPER_URL = 'https://www.infernos.co.in/';
