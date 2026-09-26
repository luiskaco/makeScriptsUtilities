# ActualizarApps

## Regla: recompilar el .exe después de tocar el .ps1

`ActualizarApps.exe` es un binario compilado con `ps2exe` a partir de
`updateScripts.ps1`. No se genera solo ni se actualiza automáticamente:
cualquier edición al `.ps1` que el usuario vaya a usar via el `.exe` queda
desactualizada en el binario hasta que se recompila a mano.

**Cada vez que se modifique `updateScripts.ps1`, recompilar el `.exe` en el
mismo paso** (no esperar a que el usuario lo pida de nuevo), con:

```powershell
Import-Module ps2exe
Invoke-ps2exe -inputFile "D:\Script\ActualizarApps\updateScripts.ps1" `
  -outputFile "D:\Script\ActualizarApps\ActualizarApps.exe" `
  -requireAdmin `
  -title "Actualizador de Aplicaciones" `
  -description "Actualiza todas las aplicaciones instaladas via winget" `
  -company "luiskaco" `
  -version "1.0.0.0"
```

- `-requireAdmin` es necesario: el manifiesto de Windows pide elevación solo
  con esta flag. Sin ella, el .exe corre sin permisos y winget falla al
  primer paquete que necesite privilegios.
- El `.exe` no se puede probar corriéndolo directo (pide UAC, que no se
  puede aprobar sin intervención del usuario) — validar la lógica corriendo
  el `.ps1` fuente primero, y solo compilar al final una vez confirmado que
  funciona.
- `ActualizarApps.GUI.ps1` es un script aparte (versión con interfaz gráfica
  de Windows Forms) y NO es la fuente de este `.exe` — no compilar desde ahí
  a menos que el usuario lo pida explícitamente.
