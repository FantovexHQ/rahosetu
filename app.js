// RAHOSETU public-site starter. Search integration will be connected after Supabase setup.
document.getElementById('search')?.addEventListener('submit', (event) => {
  event.preventDefault();
  const category = document.getElementById('category')?.value || 'all';
  const keyword = document.getElementById('keyword')?.value.trim() || '';
  const params = new URLSearchParams();
  if (category !== 'all') params.set('category', category);
  if (keyword) params.set('q', keyword);
  window.location.href = `search.html?${params.toString()}`;
});
