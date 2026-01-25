# Proyecto-Auth-FIS

# Servicio Integrado de Directorio y Autenticación (FIS)

**Estudiante:** Sergio Vite  
**Asignatura:** Computacion Distribuida
**Facultad:** Facultad de Ingeniería de Sistemas (FIS)

## Descripción del Proyecto
Este proyecto implementa un prototipo funcional de una infraestructura de autenticación centralizada y gestión de directorio para la FIS. El sistema integra cuatro servicios críticos en un entorno Linux:

* **DNS:** Resolución de nombres de dominio para `svite.com`.
* **NTP:** Sincronización de tiempo para asegurar la validez de los tickets de seguridad.
* **OpenLDAP:** Directorio jerárquico de usuarios (Organizado en Estudiantes y Docentes).
* **Kerberos (MIT):** Protocolo de autenticación segura mediante tickets (Realm: `SVITE.COM`).


## Instalación y Despliegue
chmod +x ViteS-Proyecto2.sh
sudo ./ViteS-Proyecto2.sh

## Probar
nslookup svite.com
ldapsearch -x -b "dc=svite,dc=com" "(objectclass=organization)"

kinit root/admin
klist
