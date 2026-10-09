const express = require('express');
const mysql   = require('mysql2/promise');
const cors    = require('cors');
const path    = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const pool = mysql.createPool({
  host:process.env.DB_HOST||'localhost', user:process.env.DB_USER||'root', password:process.env.DB_PASSWORD||'',
  database:process.env.DB_NAME||'new_schema', waitForConnections:true, connectionLimit:10
});

async function q(sql, p=[])  { const [r]=await pool.execute(sql,p); return r; }
async function q1(sql, p=[]) { const [r]=await pool.execute(sql,p); return r[0]||null; }

app.get('/api/meta/subeler',    async(_,res)=>{ try{res.json(await q('SELECT BranchNo,BranchName FROM BRANCH ORDER BY BranchName'))}catch(e){res.status(500).json({error:e.message})}});
app.get('/api/meta/kategoriler',async(_,res)=>{ try{res.json(await q('SELECT TypeID,TypeName FROM PRODUCT_TYPE ORDER BY TypeName'))}catch(e){res.status(500).json({error:e.message})}});
app.get('/api/meta/musteriler', async(_,res)=>{ try{res.json(await q('SELECT CustomerID,CONCAT(FirstName," ",LastName) AS Ad FROM CUSTOMER ORDER BY Ad'))}catch(e){res.status(500).json({error:e.message})}});
app.get('/api/meta/personel',   async(_,res)=>{ try{res.json(await q('SELECT StaffID,CONCAT(FirstName," ",LastName) AS Ad FROM STAFF ORDER BY Ad'))}catch(e){res.status(500).json({error:e.message})}});
app.get('/api/meta/urunler',    async(_,res)=>{ try{res.json(await q('SELECT p.ProductID,p.ProductName,p.UnitPrice AS Price,pt.TypeName FROM PRODUCT p JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID ORDER BY pt.TypeName,p.ProductName'))}catch(e){res.status(500).json({error:e.message})}});

app.get('/api/dashboard', async(_,res)=>{
  try{
    const [gelir]   =await q('SELECT COALESCE(SUM(TotalAmount),0) AS toplam FROM SALE');
    const [satis]   =await q('SELECT COUNT(*) AS adet FROM SALE');
    const [musteri] =await q('SELECT COUNT(*) AS adet FROM CUSTOMER');
    const [kritik]  =await q('SELECT COUNT(*) AS adet FROM IN_STOCK ist JOIN PRODUCT p ON p.ProductID=ist.ProductID JOIN PRODUCT_TYPE pt ON pt.TypeID=p.TypeID WHERE ist.StockQty<=pt.ReorderLevel');
    const son5      =await q("SELECT s.SaleNo,DATE_FORMAT(s.SaleDate,'%d.%m.%Y') AS Tarih,CONCAT(st.FirstName,' ',st.LastName) AS Personel,b.BranchName AS Sube,s.TotalAmount FROM SALE s JOIN STAFF st ON s.StaffID=st.StaffID JOIN BRANCH b ON s.BranchNo=b.BranchNo ORDER BY s.SaleDate DESC LIMIT 5");
    const subeGelir =await q('SELECT b.BranchName,COALESCE(SUM(s.TotalAmount),0) AS Gelir FROM BRANCH b LEFT JOIN SALE s ON s.BranchNo=b.BranchNo GROUP BY b.BranchNo,b.BranchName');
    const kritikList=await q('SELECT b.BranchName,p.ProductName,ist.StockQty,pt.ReorderLevel FROM IN_STOCK ist JOIN BRANCH b ON ist.BranchNo=b.BranchNo JOIN PRODUCT p ON ist.ProductID=p.ProductID JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID WHERE ist.StockQty<=pt.ReorderLevel ORDER BY ist.StockQty LIMIT 10');
    res.json({gelir:gelir.toplam,satis:satis.adet,musteri:musteri.adet,kritik:kritik.adet,son5,subeGelir,kritikList});
  }catch(e){res.status(500).json({error:e.message})}
});

app.get('/api/urunler', async(_,res)=>{
  try{res.json(await q(
    'SELECT p.ProductID,p.ProductName,p.UnitPrice,COALESCE(p.Barcode,"–") AS Barcode,p.TypeID,pt.TypeName,p.ExpiryDate '+
    'FROM PRODUCT p JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID ORDER BY pt.TypeName,p.ProductName'
  ))}catch(e){res.status(500).json({error:e.message})}
});
app.post('/api/urunler', async(req,res)=>{
  const {ProductName,UnitPrice,TypeID,Barcode,ExpiryDate}=req.body;
  if(!ProductName||!UnitPrice||!TypeID) return res.status(400).json({error:'Ürün adı, fiyat ve kategori zorunludur'});
  try{
    const r=await q('INSERT INTO PRODUCT (ProductName,UnitPrice,TypeID,Barcode,ExpiryDate) VALUES (?,?,?,?,?)',
      [ProductName,UnitPrice,TypeID,Barcode||null,ExpiryDate||null]);
    res.json({ok:true,id:r.insertId});
  }catch(e){res.status(500).json({error:e.message})}
});
app.put('/api/urunler/:id', async(req,res)=>{
  const {ProductName,UnitPrice,TypeID,Barcode,ExpiryDate}=req.body;
  try{
    await q('UPDATE PRODUCT SET ProductName=?,UnitPrice=?,TypeID=?,Barcode=?,ExpiryDate=? WHERE ProductID=?',
      [ProductName,UnitPrice,TypeID,Barcode||null,ExpiryDate||null,req.params.id]);
    res.json({ok:true});
  }catch(e){res.status(500).json({error:e.message})}
});
app.delete('/api/urunler/:id', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const id=req.params.id;
    const [[{satisVar}]]=await conn.execute('SELECT COUNT(*) AS satisVar FROM SALE_LINE WHERE ProductID=?',[id]);
    if(satisVar>0){
      await conn.rollback();
      return res.status(400).json({error:'Bu ürün satış kayıtlarında kullanılmış, silinemez.'});
    }
    await conn.execute('DELETE FROM SUPPLIED_BY WHERE ProductID=?',[id]);
    await conn.execute('DELETE FROM IN_STOCK WHERE ProductID=?',[id]);
    await conn.execute('DELETE FROM PRODUCT WHERE ProductID=?',[id]);
    await conn.commit();
    res.json({ok:true});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});

app.get('/api/stok', async(_,res)=>{
  try{res.json(await q(
    "SELECT ist.BranchNo,ist.ProductID,b.BranchName,p.ProductName,pt.TypeName,ist.StockQty,pt.ReorderLevel,"+
    "CASE WHEN ist.StockQty<=pt.ReorderLevel THEN 'KRİTİK' ELSE 'NORMAL' END AS Durum "+
    "FROM IN_STOCK ist JOIN BRANCH b ON ist.BranchNo=b.BranchNo JOIN PRODUCT p ON ist.ProductID=p.ProductID "+
    "JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID ORDER BY Durum DESC,ist.StockQty"
  ))}catch(e){res.status(500).json({error:e.message})}
});
app.put('/api/stok', async(req,res)=>{
  const {BranchNo,ProductID,StockQty}=req.body;
  if(Number(StockQty)<0) return res.status(400).json({error:'Stok miktarı negatif olamaz'});
  try{
    await q('UPDATE IN_STOCK SET StockQty=? WHERE BranchNo=? AND ProductID=?',[StockQty,BranchNo,ProductID]);
    res.json({ok:true});
  }catch(e){res.status(500).json({error:e.message})}
});

app.get('/api/satislar', async(_,res)=>{
  try{res.json(await q(
    "SELECT s.SaleNo,DATE_FORMAT(s.SaleDate,'%d.%m.%Y %H:%i') AS Tarih,"+
    "CONCAT(st.FirstName,' ',st.LastName) AS Personel,b.BranchName AS Sube,"+
    "COALESCE(CONCAT(c.FirstName,' ',c.LastName),'Anonim') AS Musteri,s.TotalAmount "+
    "FROM SALE s JOIN STAFF st ON s.StaffID=st.StaffID JOIN BRANCH b ON s.BranchNo=b.BranchNo "+
    "LEFT JOIN CUSTOMER c ON s.CustomerID=c.CustomerID ORDER BY s.SaleDate DESC"
  ))}catch(e){res.status(500).json({error:e.message})}
});
app.get('/api/satislar/:id', async(req,res)=>{
  try{
    const kalemler=await q(
      "SELECT sl.LineNo,p.ProductName,sl.Quantity,sl.UnitPrice,sl.Quantity*sl.UnitPrice AS Toplam "+
      "FROM SALE_LINE sl JOIN PRODUCT p ON sl.ProductID=p.ProductID WHERE sl.SaleNo=?",[req.params.id]);
    const odemeler=await q(
      "SELECT PaymentType,Amount,DATE_FORMAT(PaymentDate,'%d.%m.%Y') AS Tarih FROM PAYMENT WHERE SaleNo=?",[req.params.id]);
    const sale=await q1(
      "SELECT s.SaleNo,DATE_FORMAT(s.SaleDate,'%d.%m.%Y %H:%i') AS Tarih,s.TotalAmount,"+
      "CONCAT(st.FirstName,' ',st.LastName) AS Personel,b.BranchName AS Sube,"+
      "COALESCE(CONCAT(c.FirstName,' ',c.LastName),'Anonim') AS Musteri "+
      "FROM SALE s JOIN STAFF st ON s.StaffID=st.StaffID JOIN BRANCH b ON s.BranchNo=b.BranchNo "+
      "LEFT JOIN CUSTOMER c ON s.CustomerID=c.CustomerID WHERE s.SaleNo=?",[req.params.id]);
    res.json({sale,kalemler,odemeler});
  }catch(e){res.status(500).json({error:e.message})}
});
app.post('/api/satislar', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const {StaffID,BranchNo,CustomerID,kalemler,odeme}=req.body;
    if(!StaffID||!BranchNo) throw new Error('Şube ve personel zorunludur');
    if(!kalemler||!kalemler.length) throw new Error('En az bir kalem gereklidir');
    const [[{maxNo}]]=await conn.execute('SELECT COALESCE(MAX(SaleNo),1000)+1 AS maxNo FROM SALE');
    await conn.execute(
      'INSERT INTO SALE (SaleNo,SaleDate,StaffID,BranchNo,CustomerID) VALUES (?,NOW(),?,?,?)',
      [maxNo,StaffID,BranchNo,CustomerID||null]);
    for(const [i,k] of kalemler.entries()){
      await conn.execute(
        'INSERT INTO SALE_LINE (SaleNo,LineNo,Quantity,UnitPrice,ProductID) VALUES (?,?,?,?,?)',
        [maxNo,i+1,k.Quantity,k.UnitPrice,k.ProductID]);
    }
    const [[{maxPay}]]=await conn.execute('SELECT COALESCE(MAX(PaymentNo),0)+1 AS maxPay FROM PAYMENT');
    await conn.execute(
      'INSERT INTO PAYMENT (PaymentNo,PaymentType,Amount,PaymentDate,SaleNo) VALUES (?,?,?,NOW(),?)',
      [maxPay,odeme.PaymentType,odeme.Amount,maxNo]);
    await conn.commit();
    res.json({ok:true,SaleNo:maxNo});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});
app.delete('/api/satislar/:id', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const id=req.params.id;
    await conn.execute('DELETE FROM PAYMENT WHERE SaleNo=?',[id]);
    await conn.execute('DELETE FROM SALE_LINE WHERE SaleNo=?',[id]);
    await conn.execute('DELETE FROM SALE WHERE SaleNo=?',[id]);
    await conn.commit();
    res.json({ok:true});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});

app.get('/api/musteriler', async(_,res)=>{
  try{res.json(await q(
    "SELECT c.CustomerID,CONCAT(c.FirstName,' ',c.LastName) AS Ad,"+
    "COALESCE(c.Phone,'–') AS Phone,COALESCE(c.Email,'–') AS Email,c.LoyaltyPoints,"+
    "DATE_FORMAT(c.RegisterDate,'%d.%m.%Y') AS KayitTarihi,"+
    "COUNT(s.SaleNo) AS AlisverisSayisi,COALESCE(SUM(s.TotalAmount),0) AS ToplamHarcama "+
    "FROM CUSTOMER c LEFT JOIN SALE s ON c.CustomerID=s.CustomerID "+
    "GROUP BY c.CustomerID ORDER BY ToplamHarcama DESC"
  ))}catch(e){res.status(500).json({error:e.message})}
});
app.get('/api/musteriler/:id', async(req,res)=>{
  try{res.json(await q1('SELECT * FROM CUSTOMER WHERE CustomerID=?',[req.params.id]))}
  catch(e){res.status(500).json({error:e.message})}
});
app.post('/api/musteriler', async(req,res)=>{
  const {FirstName,LastName,Phone,Email,LoyaltyPoints}=req.body;
  if(!FirstName||!LastName) return res.status(400).json({error:'Ad ve soyad zorunludur'});
  try{
    const r=await q(
      'INSERT INTO CUSTOMER (FirstName,LastName,Phone,Email,LoyaltyPoints,RegisterDate) VALUES (?,?,?,?,?,CURDATE())',
      [FirstName,LastName,Phone||null,Email||null,LoyaltyPoints||0]);
    res.json({ok:true,id:r.insertId});
  }catch(e){res.status(500).json({error:e.message})}
});
app.put('/api/musteriler/:id', async(req,res)=>{
  const {FirstName,LastName,Phone,Email,LoyaltyPoints}=req.body;
  try{
    await q('UPDATE CUSTOMER SET FirstName=?,LastName=?,Phone=?,Email=?,LoyaltyPoints=? WHERE CustomerID=?',
      [FirstName,LastName,Phone||null,Email||null,LoyaltyPoints||0,req.params.id]);
    res.json({ok:true});
  }catch(e){res.status(500).json({error:e.message})}
});
app.delete('/api/musteriler/:id', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const id=req.params.id;
    await conn.execute('UPDATE SALE SET CustomerID=NULL WHERE CustomerID=?',[id]);
    await conn.execute('DELETE FROM CUSTOMER WHERE CustomerID=?',[id]);
    await conn.commit();
    res.json({ok:true});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});

app.get('/api/personel', async(_,res)=>{
  try{res.json(await q(
    "SELECT st.StaffID,CONCAT(st.FirstName,' ',st.LastName) AS Ad,st.Position AS Rol,"+
    "st.Salary,st.Phone,st.BirthDate,"+
    "GROUP_CONCAT(DISTINCT b.BranchName ORDER BY b.BranchName SEPARATOR ', ') AS Subeler,"+
    "COALESCE(CONCAT(sup.FirstName,' ',sup.LastName),'–') AS Supervisor "+
    "FROM STAFF st "+
    "LEFT JOIN WORKS_IN wi ON st.StaffID=wi.StaffID "+
    "LEFT JOIN BRANCH b ON wi.BranchNo=b.BranchNo "+
    "LEFT JOIN STAFF sup ON st.SupervisorID=sup.StaffID "+
    "GROUP BY st.StaffID ORDER BY st.LastName"
  ))}catch(e){res.status(500).json({error:e.message})}
});
app.get('/api/personel/:id', async(req,res)=>{
  try{
    const staff=await q1('SELECT * FROM STAFF WHERE StaffID=?',[req.params.id]);
    const subeler=await q('SELECT BranchNo FROM WORKS_IN WHERE StaffID=?',[req.params.id]);
    res.json({...staff, subeler:subeler.map(s=>s.BranchNo)});
  }catch(e){res.status(500).json({error:e.message})}
});
app.post('/api/personel', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const {FirstName,LastName,Position,Salary,BirthDate,Phone,SupervisorID,BranchNo,ShiftHours}=req.body;
    if(!FirstName||!LastName) throw new Error('Ad ve soyad zorunludur');
    const [r]=await conn.execute(
      'INSERT INTO STAFF (FirstName,LastName,Position,Salary,BirthDate,Phone,SupervisorID) VALUES (?,?,?,?,?,?,?)',
      [FirstName,LastName,Position||null,Salary||null,BirthDate||null,Phone||null,SupervisorID||null]);
    if(BranchNo){
      await conn.execute('INSERT INTO WORKS_IN (StaffID,BranchNo,ShiftHours) VALUES (?,?,?)',
        [r.insertId,BranchNo,ShiftHours||40]);
    }
    await conn.commit();
    res.json({ok:true,id:r.insertId});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});
app.put('/api/personel/:id', async(req,res)=>{
  const {FirstName,LastName,Position,Salary,BirthDate,Phone,SupervisorID}=req.body;
  try{
    await q('UPDATE STAFF SET FirstName=?,LastName=?,Position=?,Salary=?,BirthDate=?,Phone=?,SupervisorID=? WHERE StaffID=?',
      [FirstName,LastName,Position||null,Salary||null,BirthDate||null,Phone||null,SupervisorID||null,req.params.id]);
    res.json({ok:true});
  }catch(e){res.status(500).json({error:e.message})}
});
app.delete('/api/personel/:id', async(req,res)=>{
  const conn=await pool.getConnection();
  try{
    await conn.beginTransaction();
    const id=req.params.id;
    const [[{satisVar}]]=await conn.execute('SELECT COUNT(*) AS satisVar FROM SALE WHERE StaffID=?',[id]);
    if(satisVar>0){
      await conn.rollback();
      return res.status(400).json({error:`Bu personelin ${satisVar} adet satış kaydı var. Önce satışları silin veya başka personele aktarın.`});
    }
    await conn.execute('UPDATE STAFF SET SupervisorID=NULL WHERE SupervisorID=?',[id]);
    await conn.execute('DELETE FROM WORKS_IN WHERE StaffID=?',[id]);
    await conn.execute('DELETE FROM STAFF WHERE StaffID=?',[id]);
    await conn.commit();
    res.json({ok:true});
  }catch(e){await conn.rollback(); res.status(500).json({error:e.message});}
  finally{conn.release()}
});

const raporlar={
  s1:`SELECT b.BranchName AS Şube,COALESCE(SUM(s.TotalAmount),0) AS ToplamGelir,COUNT(s.SaleNo) AS SatışSayısı FROM BRANCH b LEFT JOIN SALE s ON b.BranchNo=s.BranchNo GROUP BY b.BranchNo,b.BranchName ORDER BY ToplamGelir DESC`,
  s2:`SELECT p.ProductName AS Ürün,pt.TypeName AS Kategori,SUM(sl.Quantity) AS ToplamAdet,ROUND(SUM(sl.Quantity*sl.UnitPrice),2) AS ToplamGelir FROM SALE_LINE sl JOIN PRODUCT p ON sl.ProductID=p.ProductID JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID GROUP BY p.ProductID,p.ProductName,pt.TypeName ORDER BY ToplamAdet DESC LIMIT 10`,
  s3:`SELECT b.BranchName AS Şube,p.ProductName AS Ürün,ist.StockQty AS MevcutStok,pt.ReorderLevel AS Eşik,pt.ReorderLevel-ist.StockQty AS Eksik FROM IN_STOCK ist JOIN BRANCH b ON ist.BranchNo=b.BranchNo JOIN PRODUCT p ON ist.ProductID=p.ProductID JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID WHERE ist.StockQty<=pt.ReorderLevel ORDER BY Eksik DESC`,
  s4:`SELECT CONCAT(c.FirstName,' ',c.LastName) AS Müşteri,COUNT(s.SaleNo) AS AlışverişSayısı,ROUND(SUM(s.TotalAmount),2) AS ToplamHarcama,c.LoyaltyPoints FROM CUSTOMER c JOIN SALE s ON c.CustomerID=s.CustomerID GROUP BY c.CustomerID HAVING ToplamHarcama>(SELECT AVG(TotalAmount) FROM SALE) ORDER BY ToplamHarcama DESC`,
  s5:`SELECT pt.TypeName AS Kategori,COUNT(DISTINCT p.ProductID) AS UrunSayisi,SUM(sl.Quantity) AS ToplamAdet,ROUND(SUM(sl.Quantity*sl.UnitPrice),2) AS ToplamGelir FROM PRODUCT_TYPE pt LEFT JOIN PRODUCT p ON pt.TypeID=p.TypeID LEFT JOIN SALE_LINE sl ON p.ProductID=sl.ProductID GROUP BY pt.TypeID,pt.TypeName ORDER BY ToplamGelir DESC`,
  s6:`SELECT CONCAT(st.FirstName,' ',st.LastName) AS Personel,st.Position AS Pozisyon,b.BranchName AS Şube,COUNT(s.SaleNo) AS SatışSayısı,COALESCE(ROUND(SUM(s.TotalAmount),2),0) AS ToplamCiro FROM STAFF st LEFT JOIN WORKS_IN wi ON st.StaffID=wi.StaffID LEFT JOIN BRANCH b ON wi.BranchNo=b.BranchNo LEFT JOIN SALE s ON st.StaffID=s.StaffID GROUP BY st.StaffID,b.BranchNo ORDER BY ToplamCiro DESC`,
  s11:`SELECT PaymentType AS ÖdemeYöntemi,COUNT(*) AS İşlemSayısı,ROUND(SUM(Amount),2) AS ToplamTutar FROM PAYMENT GROUP BY PaymentType ORDER BY ToplamTutar DESC`,
  s19:`SELECT pt.TypeName AS Kategori,p.ProductName AS Ürün,COALESCE(SUM(sl.Quantity),0) AS ToplamSatış,RANK() OVER(PARTITION BY pt.TypeID ORDER BY COALESCE(SUM(sl.Quantity),0) DESC) AS Sıra FROM PRODUCT p JOIN PRODUCT_TYPE pt ON p.TypeID=pt.TypeID LEFT JOIN SALE_LINE sl ON p.ProductID=sl.ProductID GROUP BY pt.TypeID,pt.TypeName,p.ProductID,p.ProductName ORDER BY pt.TypeName,Sıra`,
  s20:`SELECT DATE_FORMAT(s.SaleDate,'%Y-%m-%d') AS Tarih,ROUND(SUM(s.TotalAmount),2) AS GünlükGelir,ROUND(SUM(SUM(s.TotalAmount)) OVER(ORDER BY DATE_FORMAT(s.SaleDate,'%Y-%m-%d')),2) AS KümülatifGelir FROM SALE s GROUP BY DATE_FORMAT(s.SaleDate,'%Y-%m-%d') ORDER BY Tarih`,
};
app.get('/api/rapor/:id', async(req,res)=>{
  const sql=raporlar[req.params.id];
  if(!sql) return res.status(404).json({error:'Rapor bulunamadı'});
  try{res.json(await q(sql))}catch(e){res.status(500).json({error:e.message})}
});

app.listen(3000,()=>console.log('Sunucu: http://localhost:3000'));
