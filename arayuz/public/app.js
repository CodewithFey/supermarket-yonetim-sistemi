const API = 'http://localhost:3000/api';
const titles = { dashboard:'Dashboard', satislar:'Satışlar', urunler:'Ürünler', stok:'Stok Durumu', musteriler:'Müşteriler', personel:'Personel', raporlar:'Raporlar' };

document.querySelectorAll('.nav-item').forEach(el =>
  el.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach(x => x.classList.remove('active'));
    el.classList.add('active');
    loadPage(el.dataset.page);
  })
);

async function api(endpoint, method='GET', body=null) {
  try {
    const opts = { method, headers:{'Content-Type':'application/json'} };
    if (body) opts.body = JSON.stringify(body);
    const r = await fetch(API + endpoint, opts);
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || 'Sunucu hatası');
    return data;
  } catch(e) {
    
    throw e;
  }
}

function fmt(n) { return Number(n).toLocaleString('tr-TR',{minimumFractionDigits:2,maximumFractionDigits:2}); }

function setContent(html) { document.getElementById('content').innerHTML = html; }

function toast(msg, type='ok') {
  const t = document.createElement('div');
  t.className = 'toast toast-' + type;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(()=>t.remove(),300); }, 3000);
}

function openModal(title, bodyHtml) {
  document.getElementById('modalTitle').textContent = title;
  document.getElementById('modalBody').innerHTML = bodyHtml;
  document.getElementById('modalOverlay').style.display = 'flex';
}
function closeModal() { document.getElementById('modalOverlay').style.display = 'none'; }
document.getElementById('modalOverlay').addEventListener('click', e => { if(e.target===e.currentTarget) closeModal(); });


function field(label, name, type='text', value='', required=false, extra='') {
  return `<div class="form-group">
    <label class="form-label">${label}${required?'<span class="req">*</span>':''}</label>
    <input class="form-input" type="${type}" name="${name}" value="${value??''}" ${required?'required':''} ${extra}>
  </div>`;
}
function selectField(label, name, options, selected='', required=false) {
  const opts = options.map(o=>`<option value="${o.val}" ${o.val==selected?'selected':''}>${o.label}</option>`).join('');
  return `<div class="form-group">
    <label class="form-label">${label}${required?'<span class="req">*</span>':''}</label>
    <select class="form-input" name="${name}" ${required?'required':''}><option value="">– Seçiniz –</option>${opts}</select>
  </div>`;
}
function formRow(...fields) { return `<div class="form-row">${fields.join('')}</div>`; }

function getForm(id) {
  const form = document.getElementById(id);
  const data = {};
  new FormData(form).forEach((v,k) => data[k]=v);
  return data;
}

function buildTable(cols, rows, opts={}) {
  if(!rows.length) return '<div class="empty">Kayıt bulunamadı.</div>';
  const keys = opts.keys || Object.keys(rows[0]);
  const head = cols.map(c=>`<th>${c}</th>`).join('') + (opts.actions?'<th style="width:110px">İşlem</th>':'');
  const body = rows.map((r,i) => {
    const tds = keys.map(k => {
      let v = r[k] ?? '–';
      if (opts.badge?.[k]) v = opts.badge[k](r[k], r);
      else if (opts.format?.[k]) v = opts.format[k](r[k], r);
      return `<td>${v}</td>`;
    }).join('');
    const act = opts.actions ? `<td>${opts.actions(r)}</td>` : '';
    return `<tr>${tds}${act}</tr>`;
  }).join('');
  return `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function actionBtns(editFn, delFn) {
  return `<button class="btn-sm btn-edit" onclick="${editFn}">Düzenle</button>
          <button class="btn-sm btn-del"  onclick="${delFn}">Sil</button>`;
}

async function pageDashboard() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const d = await api('/dashboard');
  const maxG = Math.max(...d.subeGelir.map(s=>+s.Gelir), 1);
  const bars = d.subeGelir.map(s=>`
    <div class="bar-item">
      <div class="bar-label"><span>${s.BranchName}</span><span><b>${fmt(s.Gelir)} ₺</b></span></div>
      <div class="bar-track"><div class="bar-fill" style="width:${(+s.Gelir/maxG*100).toFixed(1)}%"></div></div>
    </div>`).join('');
  const kritikRows = d.kritikList.map(r=>
    `<tr><td>${r.BranchName}</td><td>${r.ProductName}</td><td><span class="tag tag-danger">${r.StockQty}</span></td><td>${r.ReorderLevel}</td></tr>`
  ).join('') || '<tr><td colspan="4" class="empty">Kritik stok yok ✓</td></tr>';
  const son5Rows = d.son5.map(r=>
    `<tr><td>#${r.SaleNo}</td><td>${r.Tarih}</td><td>${r.Sube}</td><td>${r.Personel}</td><td><b>${fmt(r.TotalAmount)} ₺</b></td></tr>`
  ).join('');
  setContent(`
    <div class="cards">
      <div class="card"><div class="card-val">${fmt(d.gelir)} ₺</div><div class="card-label">Toplam Gelir</div></div>
      <div class="card card-success"><div class="card-val">${d.satis}</div><div class="card-label">Toplam Satış</div></div>
      <div class="card"><div class="card-val">${d.musteri}</div><div class="card-label">Kayıtlı Müşteri</div></div>
      <div class="card card-danger"><div class="card-val">${d.kritik}</div><div class="card-label">Kritik Stok</div></div>
    </div>
    <div class="grid2">
      <div class="panel">
        <div class="panel-header">Son Satışlar</div>
        <div class="table-wrap"><table><thead><tr><th>#</th><th>Tarih</th><th>Şube</th><th>Personel</th><th>Toplam</th></tr></thead><tbody>${son5Rows}</tbody></table></div>
      </div>
      <div class="panel"><div class="panel-header">Şube Gelir Dağılımı</div><div class="bar-list">${bars}</div></div>
    </div>
    <div class="panel">
      <div class="panel-header">Kritik Stok Ürünleri</div>
      <div class="table-wrap"><table><thead><tr><th>Şube</th><th>Ürün</th><th>Mevcut Stok</th><th>Eşik</th></tr></thead><tbody>${kritikRows}</tbody></table></div>
    </div>`);
}

async function pageSatislar() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const rows = await api('/satislar');
  const tablo = buildTable(
    ['Fiş No','Tarih','Personel','Şube','Müşteri','Toplam'],
    rows,
    { keys:['SaleNo','Tarih','Personel','Sube','Musteri','TotalAmount'],
      format:{ TotalAmount: v=>`<b>${fmt(v)} ₺</b>` },
      actions: r=>`<button class="btn-sm btn-info" onclick="satisDetay(${r.SaleNo})">Detay</button>
                   <button class="btn-sm btn-del" onclick="satisSil(${r.SaleNo})">Sil</button>`
    }
  );
  setContent(`
    <div class="panel">
      <div class="panel-header">
         Satışlar <span class="rec-count">${rows.length} kayıt</span>
        <button class="btn-primary" onclick="yeniSatisModal()">+ Yeni Satış</button>
      </div>
      ${tablo}
    </div>`);
}

async function satisDetay(id) {
  const d = await api(`/satislar/${id}`);
  const kalemHtml = `<table><thead><tr><th>#</th><th>Ürün</th><th>Adet</th><th>Birim</th><th>Toplam</th></tr></thead><tbody>
    ${d.kalemler.map(r=>`<tr><td>${r.LineNo}</td><td>${r.ProductName}</td><td>${r.Quantity}</td><td>${fmt(r.UnitPrice)} ₺</td><td><b>${fmt(r.Toplam)} ₺</b></td></tr>`).join('')}
  </tbody></table>`;
  const odemeHtml = `<table><thead><tr><th>Yöntem</th><th>Tutar</th><th>Tarih</th></tr></thead><tbody>
    ${d.odemeler.map(r=>`<tr><td>${r.PaymentType}</td><td><b>${fmt(r.Amount)} ₺</b></td><td>${r.Tarih}</td></tr>`).join('')}
  </tbody></table>`;
  openModal(`Satış #${id} Detayı`,`
    <div class="modal-section"><h4>Ürün Kalemleri</h4><div class="table-wrap">${kalemHtml}</div></div>
    <div class="modal-section"><h4>Ödemeler</h4><div class="table-wrap">${odemeHtml}</div></div>`);
}

async function satisSil(id) {
  if(!window.confirm(`Satış #${id} silinsin mi? (Kalemler de silinir)`)) return;
  try { await api(`/satislar/${id}`,'DELETE'); toast('Satış silindi'); pageSatislar(); }
  catch(e) { toast(e.message,'err'); }
}

async function yeniSatisModal() {
  const [subeler, musteriler, personelMeta, urunMeta] = await Promise.all([
    api('/meta/subeler'), api('/meta/musteriler'), api('/meta/personel'), api('/meta/urunler')
  ]);
  const subeOpts   = subeler.map(s=>({val:s.BranchNo, label:s.BranchName}));
  const mustOpts   = musteriler.map(m=>({val:m.CustomerID, label:m.Ad}));
  const persOpts   = personelMeta.map(p=>({val:p.StaffID, label:p.Ad}));
  const urunOpts   = urunMeta.map(u=>({val:u.ProductID, label:`${u.ProductName} (${fmt(u.Price)} ₺)`}));

  openModal('Yeni Satış', `
    <form id="satisForm">
      <div class="form-section-title">Satış Bilgileri</div>
      ${formRow(
        selectField('Şube','BranchNo',subeOpts,'',true),
        selectField('Personel','StaffID',persOpts,'',true)
      )}
      ${selectField('Müşteri (opsiyonel)','CustomerID',mustOpts)}
      <div class="form-section-title">Ürün Kalemleri</div>
      <div id="kalemler"></div>
      <button type="button" class="btn-outline" onclick="kalemEkle()">+ Kalem Ekle</button>
      <div class="form-section-title" style="margin-top:16px">Ödeme</div>
      ${formRow(
        selectField('Ödeme Yöntemi','PaymentType',[
          {val:'Nakit',label:'Nakit'},{val:'Kredi Kartı',label:'Kredi Kartı'},
          {val:'Banka Kartı',label:'Banka Kartı'},{val:'Sadakat Puanı',label:'Sadakat Puanı'}
        ],'Nakit',true),
        field('Tutar (₺)','OdemeAmount','number','',true,'step="0.01" min="0.01"')
      )}
      <div style="margin-top:18px;display:flex;gap:10px;justify-content:flex-end">
        <button type="button" class="btn-outline" onclick="closeModal()">İptal</button>
        <button type="submit" class="btn-primary"> Kaydet</button>
      </div>
    </form>`);

  window._urunOpts = urunMeta.map(u=>({...u, Price: u.Price ?? u.UnitPrice}));
  window._kalemIndex = 0;
  kalemEkle();

  document.getElementById('satisForm').onsubmit = async e => {
    e.preventDefault();
    try {
      const fd = new FormData(e.target);
      const kalemDivs = document.querySelectorAll('.kalem-row');
      const kalemler = [...kalemDivs].map(d => ({
        ProductID: d.querySelector('[name="ProductID"]').value,
        Quantity:  d.querySelector('[name="Quantity"]').value,
        UnitPrice: d.querySelector('[name="UnitPrice"]').value,
      })).filter(k=>k.ProductID && k.Quantity);
      if(!kalemler.length) { toast('En az bir kalem ekleyin','err'); return; }
      const body = {
        StaffID:    fd.get('StaffID'),
        BranchNo:   fd.get('BranchNo'),
        CustomerID: fd.get('CustomerID')||null,
        kalemler,
        odeme: { PaymentType: fd.get('PaymentType'), Amount: fd.get('OdemeAmount') }
      };
      const r = await api('/satislar','POST',body);
      toast(`Satış #${r.SaleNo} oluşturuldu`);
      closeModal(); pageSatislar();
    } catch(e) { toast(e.message,'err'); }
  };
}

window.kalemEkle = function() {
  const idx = window._kalemIndex++;
  const opts = window._urunOpts.map(u=>`<option value="${u.ProductID}" data-price="${u.Price}">${u.ProductName} (${fmt(u.Price)} ₺)</option>`).join('');
  const div = document.createElement('div');
  div.className = 'kalem-row';
  div.innerHTML = `
    <div class="form-row" style="align-items:flex-end;gap:8px">
      <div class="form-group" style="flex:2">
        <label class="form-label">Ürün</label>
        <select class="form-input kalem-urun" name="ProductID" onchange="urunSecildi(this)">
          <option value="">– Seçiniz –</option>${opts}
        </select>
      </div>
      <div class="form-group" style="flex:1">
        <label class="form-label">Adet</label>
        <input class="form-input" type="number" name="Quantity" min="1" value="1">
      </div>
      <div class="form-group" style="flex:1">
        <label class="form-label">Birim Fiyat</label>
        <input class="form-input kalem-fiyat" type="number" name="UnitPrice" step="0.01" min="0">
      </div>
      <button type="button" class="btn-sm btn-del" style="margin-bottom:4px" onclick="this.closest('.kalem-row').remove()">Sil</button>
    </div>`;
  document.getElementById('kalemler').appendChild(div);
};

window.urunSecildi = function(sel) {
  const price = sel.options[sel.selectedIndex]?.dataset.price || '';
  sel.closest('.kalem-row').querySelector('.kalem-fiyat').value = price;
};

async function pageUrunler() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const rows = await api('/urunler');
  const tablo = buildTable(
    ['ID','Ürün Adı','Kategori','Fiyat','Barkod','SKT'],
    rows,
    { keys:['ProductID','ProductName','TypeName','UnitPrice','Barcode','ExpiryDate'],
      format:{
        UnitPrice: v=>`<b>${fmt(v)} ₺</b>`,
        ExpiryDate: v=>v?v.slice(0,10):'–'
      },
      actions: r=>`${actionBtns(`urunDuzenle(${r.ProductID})`,`urunSil(${r.ProductID})`)}`
    }
  );
  setContent(`
    <div class="panel">
      <div class="panel-header"> Ürünler <span class="rec-count">${rows.length} ürün</span>
        <button class="btn-primary" onclick="urunFormAc()">+ Yeni Ürün</button>
      </div>${tablo}
    </div>`);
}

async function urunFormAc(id=null) {
  const kategoriler = await api('/meta/kategoriler');
  const katOpts = kategoriler.map(k=>({val:k.TypeID,label:k.TypeName}));
  let u = {};
  if(id) u = (await api('/urunler')).find(x=>x.ProductID==id)||{};
  openModal(id?'Ürün Düzenle':'Yeni Ürün',`
    <form id="urunForm">
      ${field('Ürün Adı','ProductName','text',u.ProductName,true)}
      ${formRow(
        field('Birim Fiyat (₺)','UnitPrice','number',u.UnitPrice,true,'step="0.01" min="0"'),
        field('Barkod','Barcode','text',u.Barcode=='–'?'':u.Barcode)
      )}
      ${formRow(
        selectField('Kategori','TypeID',katOpts,u.TypeID,true),
        field('Son Kullanma Tarihi','ExpiryDate','date',u.ExpiryDate?u.ExpiryDate.slice(0,10):'')
      )}
      <div style="margin-top:18px;display:flex;gap:10px;justify-content:flex-end">
        <button type="button" class="btn-outline" onclick="closeModal()">İptal</button>
        <button type="submit" class="btn-primary"> Kaydet</button>
      </div>
    </form>`);
  document.getElementById('urunForm').onsubmit = async e => {
    e.preventDefault();
    const data = getForm('urunForm');
    try {
      if(id) { await api(`/urunler/${id}`,'PUT',data); toast('Ürün güncellendi'); }
      else    { await api('/urunler','POST',data); toast('Ürün eklendi'); }
      closeModal(); pageUrunler();
    } catch(e) { toast(e.message,'err'); }
  };
}
async function urunDuzenle(id) { await urunFormAc(id); }
async function urunSil(id) {
  if(!window.confirm('Ürünü silmek istediğinize emin misiniz?')) return;
  try { await api(`/urunler/${id}`,'DELETE'); toast('Ürün silindi'); pageUrunler(); }
  catch(e) { toast(e.message,'err'); }
}

async function pageStok() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const rows = await api('/stok');
  const tablo = buildTable(
    ['Şube','Ürün','Kategori','Stok','Eşik','Durum'],
    rows,
    { keys:['BranchName','ProductName','TypeName','StockQty','ReorderLevel','Durum'],
      badge:{ Durum: v=>`<span class="tag ${v==='KRİTİK'?'tag-danger':'tag-success'}">${v}</span>` },
      format:{ StockQty:(v,r)=>r.Durum==='KRİTİK'?`<b style="color:#111">${v}</b>`:v },
      actions: r=>`<button class="btn-sm btn-edit" onclick="stokGuncelle(${r.BranchNo},${r.ProductID},'${r.BranchName}','${r.ProductName}',${r.StockQty})">Düzenle</button>`
    }
  );
  setContent(`
    <div class="panel">
      <div class="panel-header"> Stok Durumu <span class="rec-count">${rows.length} kayıt</span></div>
      ${tablo}
    </div>`);
}

function stokGuncelle(branchNo, productID, sube, urun, mevcutStok) {
  openModal('Stok Güncelle',`
    <form id="stokForm">
      <div class="info-box"> <b>${sube}</b> — ${urun}</div>
      ${field('Yeni Stok Miktarı','StockQty','number',mevcutStok,true,'min="0"')}
      <div style="margin-top:18px;display:flex;gap:10px;justify-content:flex-end">
        <button type="button" class="btn-outline" onclick="closeModal()">İptal</button>
        <button type="submit" class="btn-primary"> Güncelle</button>
      </div>
    </form>`);
  document.getElementById('stokForm').onsubmit = async e => {
    e.preventDefault();
    const StockQty = document.querySelector('[name="StockQty"]').value;
    try {
      await api('/stok','PUT',{BranchNo:branchNo, ProductID:productID, StockQty});
      toast('Stok güncellendi'); closeModal(); pageStok();
    } catch(e) { toast(e.message,'err'); }
  };
}

async function pageMusteriler() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const rows = await api('/musteriler');
  const tablo = buildTable(
    ['ID','Ad Soyad','Telefon','E-posta','Puan','Alışveriş','Harcama','Kayıt Tarihi'],
    rows,
    { keys:['CustomerID','Ad','Phone','Email','LoyaltyPoints','AlisverisSayisi','ToplamHarcama','KayitTarihi'],
      format:{
        ToplamHarcama: v=>`<b>${fmt(v)} ₺</b>`,
        LoyaltyPoints: v=>`<span class="tag tag-info">${v}</span>`
      },
      actions: r=>`${actionBtns(`musteriDuzenle(${r.CustomerID})`,`musteriSil(${r.CustomerID})`)}`
    }
  );
  setContent(`
    <div class="panel">
      <div class="panel-header"> Müşteriler <span class="rec-count">${rows.length} müşteri</span>
        <button class="btn-primary" onclick="musteriFormAc()">+ Yeni Müşteri</button>
      </div>${tablo}
    </div>`);
}

async function musteriFormAc(id=null) {
  let m = {};
  if(id) m = await api(`/musteriler/${id}`);
  openModal(id?'Müşteri Düzenle':'Yeni Müşteri',`
    <form id="musteriForm">
      ${formRow(field('Ad','FirstName','text',m.FirstName,true), field('Soyad','LastName','text',m.LastName,true))}
      ${formRow(field('Telefon','Phone','text',m.Phone), field('E-posta','Email','email',m.Email))}
      ${field('Sadakat Puanı','LoyaltyPoints','number',m.LoyaltyPoints??0,false,'min="0"')}
      <div style="margin-top:18px;display:flex;gap:10px;justify-content:flex-end">
        <button type="button" class="btn-outline" onclick="closeModal()">İptal</button>
        <button type="submit" class="btn-primary"> Kaydet</button>
      </div>
    </form>`);
  document.getElementById('musteriForm').onsubmit = async e => {
    e.preventDefault();
    const data = getForm('musteriForm');
    try {
      if(id) { await api(`/musteriler/${id}`,'PUT',data); toast('Müşteri güncellendi'); }
      else    { await api('/musteriler','POST',data); toast('Müşteri eklendi'); }
      closeModal(); pageMusteriler();
    } catch(e) { toast(e.message,'err'); }
  };
}
async function musteriDuzenle(id) { await musteriFormAc(id); }
async function musteriSil(id) {
  if(!window.confirm('Müşteriyi silmek istediğinize emin misiniz?')) return;
  try { await api(`/musteriler/${id}`,'DELETE'); toast('Müşteri silindi'); pageMusteriler(); }
  catch(e) { toast(e.message,'err'); }
}

async function pagePersonel() {
  setContent('<div class="loading">Yükleniyor...</div>');
  const rows = await api('/personel');
  const tablo = buildTable(
    ['ID','Ad Soyad','Pozisyon','Maaş','Telefon','Şubeler','Süpervizör'],
    rows,
    { keys:['StaffID','Ad','Rol','Salary','Phone','Subeler','Supervisor'],
      format:{ Salary: v=>v?`${fmt(v)} ₺`:'–', Phone: v=>v||'–', Subeler: v=>v||'–' },
      actions: r=>`${actionBtns(`personelDuzenle(${r.StaffID})`,`personelSil(${r.StaffID})`)}`
    }
  );
  setContent(`
    <div class="panel">
      <div class="panel-header"> Personel <span class="rec-count">${rows.length} personel</span>
        <button class="btn-primary" onclick="personelFormAc()">+ Yeni Personel</button>
      </div>${tablo}
    </div>`);
}

async function personelFormAc(id=null) {
  const [subeler, persListesi] = await Promise.all([api('/meta/subeler'), api('/meta/personel')]);
  const subeOpts = subeler.map(s=>({val:s.BranchNo,label:s.BranchName}));
  const supOpts  = persListesi.filter(p=>p.StaffID!=id).map(p=>({val:p.StaffID,label:p.Ad}));
  let p = {};
  if(id) p = await api(`/personel/${id}`);
  const ilkSube = p.subeler?.[0] || '';
  openModal(id?'Personel Düzenle':'Yeni Personel',`
    <form id="personelForm">
      ${formRow(field('Ad','FirstName','text',p.FirstName,true), field('Soyad','LastName','text',p.LastName,true))}
      ${formRow(field('Pozisyon','Position','text',p.Position), field('Maaş (₺)','Salary','number',p.Salary||'','','step="0.01" min="0"'))}
      ${formRow(field('Telefon','Phone','text',p.Phone), field('Doğum Tarihi','BirthDate','date',p.BirthDate?p.BirthDate.slice(0,10):''))}
      ${!id ? formRow(
          selectField('Çalıştığı Şube','BranchNo',subeOpts,ilkSube),
          field('Shift Saati','ShiftHours','number','40','','min="1" max="60"')
        ) : ''}
      ${selectField('Süpervizör','SupervisorID',supOpts,p.SupervisorID)}
      <div style="margin-top:18px;display:flex;gap:10px;justify-content:flex-end">
        <button type="button" class="btn-outline" onclick="closeModal()">İptal</button>
        <button type="submit" class="btn-primary"> Kaydet</button>
      </div>
    </form>`);
  document.getElementById('personelForm').onsubmit = async e => {
    e.preventDefault();
    const data = getForm('personelForm');
    try {
      if(id) { await api(`/personel/${id}`,'PUT',data); toast('Personel güncellendi'); }
      else    { await api('/personel','POST',data); toast('Personel eklendi'); }
      closeModal(); pagePersonel();
    } catch(e) { toast(e.message,'err'); }
  };
}
async function personelDuzenle(id) { await personelFormAc(id); }
async function personelSil(id) {
  if(!window.confirm('Personeli silmek istediğinize emin misiniz?')) return;
  try { await api(`/personel/${id}`,'DELETE'); toast('Personel silindi'); pagePersonel(); }
  catch(e) { toast(e.message,'err'); }
}

const raporMeta = [
  {id:'s1', label:'Şube Gelirleri'},
  {id:'s2', label:'En Çok Satanlar'},
  {id:'s3', label:'Kritik Stok'},
  {id:'s4', label:'Üst Müşteriler'},
  {id:'s6', label:'Personel Performansı'},
  {id:'s11', label:'Ödeme Analizi'},
  {id:'s19', label:'Kategori Sıralaması'},
  {id:'s20', label:'Kümülatif Gelir'},
];
async function pageRaporlar(aktif='s1') {
  const btns = raporMeta.map(r=>
    `<div class="rapor-btn${r.id===aktif?' active':''}" onclick="loadRapor('${r.id}')">
      ${r.label}
    </div>`).join('');
  setContent(`<div class="rapor-grid">${btns}</div><div class="panel" id="raporPanel"><div class="loading">Yükleniyor...</div></div>`);
  loadRapor(aktif);
}
async function loadRapor(id) {
  document.querySelectorAll('.rapor-btn').forEach(b=>b.classList.remove('active'));
  document.querySelector(`[onclick="loadRapor('${id}')"]`)?.classList.add('active');
  const panel = document.getElementById('raporPanel');
  if(!panel) return;
  panel.innerHTML = '<div class="loading">Yükleniyor...</div>';
  const rows = await api(`/rapor/${id}`);
  const meta = raporMeta.find(r=>r.id===id);
  const keys = rows.length ? Object.keys(rows[0]) : [];
  const head = keys.map(c=>`<th>${c}</th>`).join('');
  const body = rows.map(r=>`<tr>${keys.map(k=>{
    const v=r[k];
    const kl=k.toLowerCase();
    if(kl.includes('gelir')||kl.includes('harcama')||kl.includes('tutar')||kl.includes('ciro'))
      return `<td><b>${fmt(v)} ₺</b></td>`;
    return `<td>${v??'–'}</td>`;
  }).join('')}</tr>`).join('')||'<tr><td colspan="20" class="empty">Sonuç yok.</td></tr>';
  panel.innerHTML = `
    <div class="panel-header">${meta?.label} <span class="rec-count">${rows.length} kayıt</span></div>
    <div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function loadPage(page) {
  document.getElementById('pageTitle').textContent = titles[page]||page;
  ({dashboard:pageDashboard, satislar:pageSatislar, urunler:pageUrunler,
    stok:pageStok, musteriler:pageMusteriler, personel:pagePersonel, raporlar:pageRaporlar})[page]?.();
}

loadPage('dashboard');
