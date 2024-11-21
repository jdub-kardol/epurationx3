# MAJ 1.0
write-output "script MAJ"
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
write-output "pas admin"
}
Else {
write-output "ADMIN OK"
}
