import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import "./config.js";
const c=window.SUPABASE_CONFIG;
export const supabase=createClient(c.url,c.publishableKey);
export async function requireStaff(){
 const {data:{user}}=await supabase.auth.getUser();
 if(!user){location.href="./index.html";throw Error("Login required")}
 const {data:profile}=await supabase.from("profiles").select("*").eq("id",user.id).maybeSingle();
 if(!profile||!["admin","editor"].includes(profile.role)){await supabase.auth.signOut();location.href="./index.html";throw Error("No staff access")}
 return {user,profile};
}
export const slugify=s=>s.normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().trim().replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");