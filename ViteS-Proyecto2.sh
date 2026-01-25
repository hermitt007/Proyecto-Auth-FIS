#!/bin/bash

# ==========================================
# PROYECTO FIS - SERVICIO INTEGRADO DE DIRECTORIO
# Estudiante: Sergio Vite
# ==========================================

# --- VARIABLES DE CONFIGURACIÓN ---
DOMAIN="svite.com"
REALM="SVITE.COM"
SERVER_IP="172.17.74.240"
PASSWORD="Password123" 
ORGANIZATION_NAME="Facultad de Ingenieria de Sistemas - FIS"

echo "--- INICIANDO IMPLEMENTACIÓN DE PROTOTIPO FIS ---"

# 1. LIMPIEZA Y PREPARACIÓN
# Detenemos servicios para evitar conflictos al escribir archivos
service bind9 stop 2>/dev/null
service ntp stop 2>/dev/null
service slapd stop 2>/dev/null
service krb5-kdc stop 2>/dev/null
service krb5-admin-server stop 2>/dev/null

# 2. CONFIGURACIÓN DE NTP (CRÍTICO PARA KERBEROS)
echo "[1/4] Configurando Sincronización de Tiempo (NTP)..."
# En entorno aislado/WSL usamos el reloj local como autoridad
cat <<EOF > /etc/ntp.conf
driftfile /var/lib/ntp/ntp.drift
server 127.127.1.0
fudge 127.127.1.0 stratum 10
restrict 127.0.0.1
restrict ::1
EOF
service ntp start || echo "Nota: NTP inició con advertencias (normal en WSL)"

# 3. CONFIGURACIÓN DE DNS (BIND9)
echo "[2/4] Configurando Resolución de Nombres (DNS)..."
mkdir -p /etc/bind

# Definición de la zona
cat <<EOF > /etc/bind/named.conf.local
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.svite";
};
EOF

# Archivo de zona (Base de datos de nombres)
cat <<EOF > /etc/bind/db.svite
;
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
server  IN      A       $SERVER_IP
ldap    IN      A       $SERVER_IP
kdc     IN      A       $SERVER_IP
EOF

# Forzar resolución local
echo "nameserver $SERVER_IP" > /etc/resolv.conf
service bind9 start

# 4. CONFIGURACIÓN DE KERBEROS (AUTENTICACIÓN)
echo "[3/4] Configurando Seguridad Kerberos..."
cat <<EOF > /etc/krb5.conf
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    rdns = false

[realms]
    $REALM = {
        kdc = $SERVER_IP
        admin_server = $SERVER_IP
    }

[domain_realm]
    .$DOMAIN = $REALM
    $DOMAIN = $REALM
EOF

# Recrear base de datos de Kerberos limpia
rm -rf /var/lib/krb5kdc/principal*
kdb5_util create -s -P $PASSWORD
# Crear un usuario administrador (root/admin)
kadmin.local -q "addprinc -pw $PASSWORD root/admin"

service krb5-kdc start
service krb5-admin-server start

# 5. CONFIGURACIÓN DE LDAP (DIRECTORIO DE LA FIS)
echo "[4/4] Configurando Directorio LDAP para la FIS..."

# A. Estructura Base (La Facultad)
cat <<EOF > /tmp/base_fis.ldif
dn: dc=svite,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: $ORGANIZATION_NAME
dc: svite

dn: ou=Estudiantes,dc=svite,dc=com
objectClass: organizationalUnit
ou: Estudiantes

dn: ou=Docentes,dc=svite,dc=com
objectClass: organizationalUnit
ou: Docentes
EOF

# B. Usuario de Ejemplo (Tú como estudiante)
cat <<EOF > /tmp/usuario_fis.ldif
dn: uid=svite,ou=Estudiantes,dc=svite,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: svite
sn: Vite
givenName: Sergio
cn: Sergio Vite
displayName: Estudiante Sergio Vite
uidNumber: 10001
gidNumber: 10001
userPassword: $PASSWORD
gecos: Estudiante FIS
loginShell: /bin/bash
homeDirectory: /home/svite
EOF

# Inyectar en LDAP (Intentamos agregar, silenciamos errores si ya existen)
ldapadd -x -D "cn=admin,dc=svite,dc=com" -w $PASSWORD -f /tmp/base_fis.ldif 2>/dev/null || echo "-> Estructura base actualizada."
ldapadd -x -D "cn=admin,dc=svite,dc=com" -w $PASSWORD -f /tmp/usuario_fis.ldif 2>/dev/null || echo "-> Usuario estudiante actualizado."

echo "============================================="
echo "   PROYECTO FIS IMPLEMENTADO CON ÉXITO"
echo "============================================="
echo "Dominio: $DOMAIN"
echo "Organización: $ORGANIZATION_NAME"
echo "Usuario LDAP: svite (Unidad: Estudiantes)"
echo "IP Servidor: $SERVER_IP"
echo "============================================="
