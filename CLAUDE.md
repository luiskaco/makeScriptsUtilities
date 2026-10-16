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
Invoke-ps2exe -inputFile "D:\LabIA\Script\ActualizarApps\updateScripts.ps1" `
  -outputFile "D:\LabIA\Script\ActualizarApps\ActualizarApps.exe" `
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
- La única fuente de `ActualizarApps.exe` es `updateScripts.ps1`.

## Regla: lo mismo para `PanelUtilidades.exe`

`PanelUtilidades\PanelUtilidades.exe` se compila desde
`PanelUtilidades\PanelUtilidades.ps1`. Cada vez que se modifique el `.ps1`,
recompilar en el mismo paso:

```powershell
Import-Module ps2exe
Invoke-ps2exe -inputFile "D:\LabIA\Script\PanelUtilidades\PanelUtilidades.ps1" `
  -outputFile "D:\LabIA\Script\PanelUtilidades\PanelUtilidades.exe" `
  -noConsole -STA -DPIAware -requireAdmin `
  -title "Utilidades de Windows" `
  -description "Panel de mantenimiento de Windows: servicios, hardware, actualizaciones y limpieza de perfil" `
  -company "luiskaco" `
  -version "1.0.0.0"
```

- `-noConsole`: es una ventana WPF. Con esta flag, todo lo que llegue al
  pipeline del script aparece como un MessageBox: los métodos que devuelven
  valor van con `[void]`, y los ejecutables externos se llaman con
  `Invoke-Native` (sin ventana), nunca con `& winget` directo.
- `-STA`: WPF no funciona en un hilo MTA.
- Para probar sin UAC: ejecutar el `.ps1` en un PowerShell `-STA` (se relanza
  elevado solo si no es admin), o compilar una copia sin `-requireAdmin` en una
  carpeta temporal.
