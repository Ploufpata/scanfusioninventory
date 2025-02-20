==============================
Instructions pour l'inventaire
==============================

**Lancer l'outil FusionInventory**
   - Exécutez Scan FusionInventory.exe.

**Création du répertoire**
   - Un dossier \FusionInventory-NoAgent sera automatiquement créé sur le bureau.

**Inventaire du PC**
   - Le PC sera analysé et son inventaire envoyé à GLPI.
   - Il pourra être retrouvé dans GLPI sous l'étiquette configurée.
   - Un fichier OCS est généré à la racine du dossier \FusionInventory-NoAgent.  
     Vous pouvez le récupérer avant de lancer la suppression.

**Modification des paramètres**
   - Vous pouvez modifier l'URL du serveur et l'étiquette (TAG) avant l'inventaire.
   - Pour cela, éditez le fichier config.ini situé dans le répertoire de l'outil.
   - Modifiez les valeurs sous les sections `[CONFIG]` :
     - `REMOTE_SERVER = https://adresse_du_serveur`
     - `TAG = NOM_PERSONNALISÉ`

**Désinstallation**
   - Une fois l'inventaire terminé, appuyez sur n'importe quelle touche pour lancer la désinstallation automatique.


