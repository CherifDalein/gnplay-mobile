Fixed bottom tab bar with a raised center action (upload/publish).
```jsx
<BottomNav active="dash" items={[
  { key: 'dash', label: 'Accueil' }, { key: 'videos', label: 'Vidéos' },
  { key: 'upload', label: 'Publier', fab: true },
  { key: 'wallet', label: 'Gains' }, { key: 'profile', label: 'Profil' }
]} />
```