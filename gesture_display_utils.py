# Exemple d'utilisation: Afficher image de geste depuis dossier Data
import os
import glob
import random

def get_gesture_image(keyword):
    """
    Récupérer une image de geste depuis le dossier Data
    
    Args:
        keyword: La lettre ou le mot (ex: 'A', 'Famille', 'Transport')
    
    Returns:
        Chemin vers une image aléatoire du geste
    """
    data_path = os.path.join('Data', keyword)
    
    if not os.path.exists(data_path):
        print(f"[WARNING] Pas de dossier pour: {keyword}")
        return None
    
    # Pour les lettres (A-Z): Liste directe des images A_0.jpg, A_1.jpg, etc.
    images = glob.glob(os.path.join(data_path, f'{keyword}_*.jpg'))
    
    # 2. Si pas trouvé, chercher TOUTE image jpg dans ce dossier
    if not images:
        images = glob.glob(os.path.join(data_path, '*.jpg'))

    # Si pas d'images trouvées, vérifier sous-dossiers (pour mots)
    if not images:
        # Lister sous-dossiers
        subdirs = [d for d in os.listdir(data_path) if os.path.isdir(os.path.join(data_path, d))]
        
        if subdirs:
            # Prendre un sous-dossier aléatoire
            random_subdir = random.choice(subdirs)
            subdir_path = os.path.join(data_path, random_subdir)
            
            # Lister images dans ce sous-dossier
            images = glob.glob(os.path.join(subdir_path, '*.jpg'))
    
    if images:
        # Retourner une image aléatoire
        print(f"[DEBUG] {len(images)} images trouvées pour {keyword}")
        return random.choice(images)
    
    print(f"[WARNING] Aucune image trouvée pour: {keyword}")
    return None


# TEST
if __name__ == "__main__":
    # Tester avec une lettre
    image_a = get_gesture_image('A')
    if image_a:
        print(f"Image lettre A: {image_a}")
    
    # Tester avec un mot
    image_famille = get_gesture_image('Famille')
    if image_famille:
        print(f"Image Famille: {image_famille}")
    
    # Tester plusieurs fois pour voir l'aléatoire
    print("\n5 images aléatoires de 'A':")
    for i in range(5):
        img = get_gesture_image('A')
        print(f"  {i+1}. {os.path.basename(img)}")
