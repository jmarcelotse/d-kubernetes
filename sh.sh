echo "# d-kubernetes" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:jmarcelotse/d-kubernetes.git
git push -u origin main
git branch develop
git checkout develop
