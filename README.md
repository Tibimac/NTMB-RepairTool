# NTMB-RepairTool
Ce script en AppleScript permet d'automatiser la réparation d'une sauvegarde réseau Time Machine endommagée.<br/>
Ce script est basé sur cet article : http://ifabtesting.net/reparer-une-sauvegarde-timemachine-sur-un-nas/<br/>

Au lancement (manuel) le script demande à l'utilisateur de sélectionner le fichier de la sauvegarde Time Machine à vérifier/réparer.<br/>
Le chemin vers le fichier de la sauvegarde est ensuite enregistré dans un fichier de préférence afin de ne plus avoir a faire cette demande à l'utilisateur.<br/>
Ensuite une vérification de l'état de la sauvegarde est faite et si une réparation est nécessaire, des commandes sont exécutées pour tenter de réparer le fichier corrompu.<br/>

Ce script n'est pas parfait (pour le moment) et peut ne pas fonctionner. Il est proposé en l'état et je ne saurais être tenu responsable d'une quelconque perte de données.
