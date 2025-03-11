import os
import shutil

# Defina as pastas que você deseja copiar
#pastas_para_copiar = [".vscode-insiders", ".vscode-cli", ".docker"]  # Substitua pelos nomes reais das pastas
pastas_para_copiar = ["Larian Studios"]
#C:\Users\marco\AppData\Local
src_base_dir = "C:\\Users\\marco\\AppData\\Local"
dst_base_dir = "D:\\userdirbackup"

# 1. Copiar as pastas
for pasta in pastas_para_copiar:
    src_path = os.path.join(src_base_dir, pasta)
    
    # Se a pasta de origem for um link simbólico, pule para a próxima iteração do loop
    if os.path.islink(src_path):
        print(f"Pasta {pasta} é um link simbólico. Pulando a cópia...")
        continue
    
    dst_path = os.path.join(dst_base_dir, pasta)
    
    if os.path.exists(dst_path):
        shutil.rmtree(dst_path)
    shutil.copytree(src_path, dst_path)
    print(f"Pasta {pasta} copiada com sucesso para {dst_path}!")

# 2. Criar links simbólicos
for pasta in pastas_para_copiar:
    src_path = os.path.join(src_base_dir, pasta)
    dst_path = os.path.join(dst_base_dir, pasta)
    
    # Se a pasta de origem for um link simbólico, pule para a próxima iteração do loop
    if os.path.islink(src_path):
        continue

    if os.path.exists(src_path):
        shutil.rmtree(src_path)
    os.symlink(dst_path, src_path, target_is_directory=True)
    print(f"Link simbólico para {pasta} criado com sucesso em {src_path}!")

print("Processo concluído!")
