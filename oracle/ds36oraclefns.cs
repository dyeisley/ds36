/*
 * DVD Store 3 Oracle Functions - ds36oraclefns.cs
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Provides interface functions for DVD Store driver program ds2xdriver.cs
 * Requires Oracle Data Provider for .NET
 * See ds2xdriver.cs for compilation and syntax
 *
 * Updated 12/29/09
 *   w/ changes for Oracle Data Provider for .NET 11g Release 1 (11.1.0.7.0) (11107_w2k8_x64_production_client.zip)
 *
 * Updated 06/24/2010 by GSK (Single instance of driver driving multiple DB instances and Parameterization of IN query)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  */

using System;
using System.Data;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using System.Threading;
using System.Diagnostics;


namespace ds2xdriver
  {
  /// <summary>
  /// ds2oraclefns.cs: DVD Store 3 Oracle Functions
  /// </summary>
  public class ds2Interface
    {
    int ds2Interfaceid;
    OracleConnection objConn;
    OracleCommand Login, New_Customer, Browse_By_Category, Browse_By_Actor, Browse_By_Title, Browse_By_Membership, New_Product, Purchase;
    OracleCommand Get_Prod_Reviews, Get_Prod_Reviews_By_Actor, Get_Prod_Reviews_By_Title, Get_Prod_Reviews_By_Date, Get_Prod_Reviews_By_Stars;
    OracleCommand New_Member, New_Prod_Review, New_Review_Helpfulness;
    OracleCommand Remove_Review_By_Product, Remove_Unhelpful_Reviews, Adjust_Prices, Mark_Specials;

    OracleParameter[] New_Customer_prm = new OracleParameter[20];
    OracleParameter[] Purchase_prm = new OracleParameter[6];
    OracleParameter[] New_Member_prm = new OracleParameter[3];
    OracleParameter[] New_Prod_Review_prm = new OracleParameter[6];
    OracleParameter[] New_Review_Helpfulness_prm = new OracleParameter[4];

    OracleParameter Purchase_prod_id_in, Purchase_qty_in;
    OracleCommand[] CostQuery = new OracleCommand[11];

    //Added by GSK (This variable will have target server name to which thread is tied to and users will login to the database on this server)
    string target_server_name;

    //Added to support multiple stores - default is 1
    int target_store_number = 1;

//
//-------------------------------------------------------------------------------------------------
//

// (Overloaded constructor to support multiple stores within single DS3 instance)
    public ds2Interface(int ds2interfaceid, string target_name, int target_store)
    {
      ds2Interfaceid = ds2interfaceid;
      target_server_name = target_name;
      target_store_number = target_store;

      string sConnectionString = "User ID=ds3;Password=ds3;Connection Timeout=120;Data Source=" + target_server_name;
      objConn = new OracleConnection(sConnectionString);

      // Set up Oracle stored procedure calls and associated parameters

      // Login
      Login = new OracleCommand("LOGIN" + target_store_number, objConn);
      Login.CommandType = CommandType.StoredProcedure;
      Login.Parameters.Add("p_username_in", OracleDbType.Varchar2);
      Login.Parameters.Add("p_password_in", OracleDbType.Varchar2);
      Login.Parameters.Add("p_customerid", OracleDbType.Int32, ParameterDirection.Output);
      Login.BindByName = true;

      // New_Customer
      New_Customer = new OracleCommand("", objConn);
      New_Customer.CommandText = "New_Customer" + target_store_number;
      New_Customer.CommandType = CommandType.StoredProcedure;
      New_Customer_prm[0] = New_Customer.Parameters.Add("firstname_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[1] = New_Customer.Parameters.Add("lastname_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[2] = New_Customer.Parameters.Add("address1_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[3] = New_Customer.Parameters.Add("address2_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[4] = New_Customer.Parameters.Add("city_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[5] = New_Customer.Parameters.Add("state_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[6] = New_Customer.Parameters.Add("zip_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Customer_prm[7] = New_Customer.Parameters.Add("country_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[8] = New_Customer.Parameters.Add("region_in", OracleDbType.Int16, ParameterDirection.Input);
      New_Customer_prm[9] = New_Customer.Parameters.Add("email_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[10] = New_Customer.Parameters.Add("phone_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[11] = New_Customer.Parameters.Add("creditcardtype_in", OracleDbType.Int16, ParameterDirection.Input);
      New_Customer_prm[12] = New_Customer.Parameters.Add("creditcard_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[13] = New_Customer.Parameters.Add("creditcardexpiration_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[14] = New_Customer.Parameters.Add("username_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[15] = New_Customer.Parameters.Add("password_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Customer_prm[16] = New_Customer.Parameters.Add("age_in", OracleDbType.Int16, ParameterDirection.Input);
      New_Customer_prm[17] = New_Customer.Parameters.Add("income_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Customer_prm[18] = New_Customer.Parameters.Add("gender_in", OracleDbType.Varchar2, 1, ParameterDirection.Input);
      New_Customer_prm[19] = New_Customer.Parameters.Add("customerid_out", OracleDbType.Int32, ParameterDirection.Output);

      //New Member
      New_Member = new OracleCommand("", objConn);
      New_Member.CommandText = "New_Member" + target_store_number;
      New_Member.CommandType = CommandType.StoredProcedure;
      New_Member_prm[0] = New_Member.Parameters.Add("customerid_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Member_prm[1] = New_Member.Parameters.Add("membershiplevel_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Member_prm[2] = New_Member.Parameters.Add("customerid_out", OracleDbType.Int32, ParameterDirection.Output);

      //Browse_By_Category
      Browse_By_Category = new OracleCommand("Browse_By_Category" + target_store_number, objConn);
      Browse_By_Category.CommandType = CommandType.StoredProcedure;
      Browse_By_Category.Parameters.Add("p_category_in", OracleDbType.Int32);
      Browse_By_Category.Parameters.Add("p_batch_size", OracleDbType.Int32);
      Browse_By_Category.Parameters.Add("p_special_in", OracleDbType.Int32);

      //Browse_By_Actor
      Browse_By_Actor = new OracleCommand("Browse_By_Actor" + target_store_number, objConn);
      Browse_By_Actor.CommandType = CommandType.StoredProcedure;
      Browse_By_Actor.Parameters.Add("p_actor_in", OracleDbType.Varchar2);
      Browse_By_Actor.Parameters.Add("p_batch_size", OracleDbType.Int32);

      //Browse_By_Title
      Browse_By_Title = new OracleCommand("Browse_By_Title" + target_store_number, objConn);
      Browse_By_Title.CommandType = CommandType.StoredProcedure;
      Browse_By_Title.Parameters.Add("p_title_in", OracleDbType.Varchar2);
      Browse_By_Title.Parameters.Add("p_batch_size", OracleDbType.Int32);

      //Browse_By_Membership
      Browse_By_Membership = new OracleCommand("BROWSE_BY_MEMBERSHIP" + target_store_number, objConn);
      Browse_By_Membership.CommandType = CommandType.StoredProcedure;
      Browse_By_Membership.Parameters.Add("p_batch_size", OracleDbType.Int32);
      Browse_By_Membership.Parameters.Add("p_membershiptype_in", OracleDbType.Int32);

      // Get_Prod_Reviews

      Get_Prod_Reviews = new OracleCommand("Get_Prod_Reviews" + target_store_number, objConn);
      Get_Prod_Reviews.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews.Parameters.Add("p_prod_in", OracleDbType.Int32, ParameterDirection.Input);
      Get_Prod_Reviews.Parameters.Add("p_batch_size", OracleDbType.Int32, ParameterDirection.Input);

      //Get_Prod_Reviews_By_Date
      Get_Prod_Reviews_By_Date = new OracleCommand("Get_Prod_Reviews_By_Date" + target_store_number, objConn);
      Get_Prod_Reviews_By_Date.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Date.Parameters.Add("p_prod_in",OracleDbType.Int32,ParameterDirection.Input);
      Get_Prod_Reviews_By_Date.Parameters.Add("p_batch_size",OracleDbType.Int32,ParameterDirection.Input);

      //Get_Prod_Reviews_By_Stars
      Get_Prod_Reviews_By_Stars = new OracleCommand("Get_Prod_Reviews_By_Stars" + target_store_number, objConn);
      Get_Prod_Reviews_By_Stars.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Stars.Parameters.Add("p_prod_in", OracleDbType.Int32, ParameterDirection.Input);
      Get_Prod_Reviews_By_Stars.Parameters.Add("p_stars_in", OracleDbType.Int32, ParameterDirection.Input);
      Get_Prod_Reviews_By_Stars.Parameters.Add("p_batch_size", OracleDbType.Int32, ParameterDirection.Input);

      //Get_Prod_Reviews_By_Title
      Get_Prod_Reviews_By_Title = new OracleCommand("Get_Prod_Reviews_By_Title" + target_store_number, objConn);
      Get_Prod_Reviews_By_Title.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Title.Parameters.Add("p_title_in", OracleDbType.Varchar2, ParameterDirection.Input);
      Get_Prod_Reviews_By_Title.Parameters.Add("p_batch_size", OracleDbType.Int32, ParameterDirection.Input);
      Get_Prod_Reviews_By_Title.Parameters.Add("p_search_depth", OracleDbType.Int32, ParameterDirection.Input);

      //Get_Prod_Reviews_By_Actor
      Get_Prod_Reviews_By_Actor = new OracleCommand("Get_Prod_Reviews_By_Actor" + target_store_number, objConn);
      Get_Prod_Reviews_By_Actor.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Actor.Parameters.Add("p_actor_in", OracleDbType.Varchar2, ParameterDirection.Input);
      Get_Prod_Reviews_By_Actor.Parameters.Add("p_batch_size", OracleDbType.Int32, ParameterDirection.Input);
      Get_Prod_Reviews_By_Actor.Parameters.Add("p_search_depth", OracleDbType.Int32, ParameterDirection.Input);

       //New Prod Reviews
      New_Prod_Review = new OracleCommand("", objConn);
      New_Prod_Review.CommandText = "New_Prod_Review" + target_store_number;
      New_Prod_Review.CommandType = CommandType.StoredProcedure;
      New_Prod_Review_prm[0] = New_Prod_Review.Parameters.Add("prod_id_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Prod_Review_prm[1] = New_Prod_Review.Parameters.Add("stars_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Prod_Review_prm[2] = New_Prod_Review.Parameters.Add("customerid_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Prod_Review_prm[3] = New_Prod_Review.Parameters.Add("review_summary_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Prod_Review_prm[4] = New_Prod_Review.Parameters.Add("review_text_in", OracleDbType.Varchar2, ParameterDirection.Input);
      New_Prod_Review_prm[5] = New_Prod_Review.Parameters.Add("review_id_out", OracleDbType.Int32, ParameterDirection.Output);

      //New Review Helpfulness
      New_Review_Helpfulness = new OracleCommand("", objConn);
      New_Review_Helpfulness.CommandText = "New_Review_Helpfulness" + target_store_number;
      New_Review_Helpfulness.CommandType = CommandType.StoredProcedure;
      New_Review_Helpfulness_prm[0] = New_Review_Helpfulness.Parameters.Add("reviewid_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Review_Helpfulness_prm[1] = New_Review_Helpfulness.Parameters.Add("customerid_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Review_Helpfulness_prm[2] = New_Review_Helpfulness.Parameters.Add("review_helpfulness_in", OracleDbType.Int32, ParameterDirection.Input);
      New_Review_Helpfulness_prm[3] = New_Review_Helpfulness.Parameters.Add("customerid_out", OracleDbType.Int32, ParameterDirection.Output);

      //New Product
      New_Product = new OracleCommand("AddNewInventoryProduct" + target_store_number, objConn);
      New_Product.CommandType = CommandType.StoredProcedure;
      New_Product.Parameters.Add("p_cat", OracleDbType.Int32);
      New_Product.Parameters.Add("p_title", OracleDbType.Varchar2);
      New_Product.Parameters.Add("p_actor", OracleDbType.Varchar2);
      New_Product.Parameters.Add("p_price", OracleDbType.Decimal);
      New_Product.Parameters.Add("p_stock", OracleDbType.Int32);
      New_Product.Parameters.Add("p_gen_id", OracleDbType.Int32, ParameterDirection.Output);

      //Purchase
      Purchase = new OracleCommand("", objConn);
      Purchase.CommandText = "Purchase" + target_store_number;
      Purchase.CommandType = CommandType.StoredProcedure;

      Purchase_prm[0] = Purchase.Parameters.Add("customerid_in", OracleDbType.Int32, ParameterDirection.Input);
      Purchase_prm[1] = Purchase.Parameters.Add("number_items", OracleDbType.Int32, ParameterDirection.Input);
      Purchase_prm[2] = Purchase.Parameters.Add("netamount_in", OracleDbType.Decimal, ParameterDirection.Input);
      Purchase_prm[3] = Purchase.Parameters.Add("taxamount_in", OracleDbType.Decimal, ParameterDirection.Input);
      Purchase_prm[4] = Purchase.Parameters.Add("totalamount_in", OracleDbType.Decimal, ParameterDirection.Input);
      Purchase_prm[5] = Purchase.Parameters.Add("neworderid_out", OracleDbType.Int32, ParameterDirection.Output);

      Purchase_prod_id_in = Purchase.Parameters.Add("prod_id_in", OracleDbType.Int32, ParameterDirection.Input);
      Purchase_prod_id_in.CollectionType = OracleCollectionType.PLSQLAssociativeArray;
      Purchase_prod_id_in.Size = 10;

      Purchase_qty_in = Purchase.Parameters.Add("qty_in", OracleDbType.Int32, ParameterDirection.Input);
      Purchase_qty_in.CollectionType = OracleCollectionType.PLSQLAssociativeArray;
      Purchase_qty_in.Size = 10;

      // Pre-compile cost query commands for cart sizes 1-10
      for (int items = 1; items <= 10; items++)
      {
        string query = "SELECT PROD_ID, PRICE FROM PRODUCTS" + target_store_number + " WHERE PROD_ID IN (";
        for (int i = 0; i < items; i++)
        {
          if (i > 0) query += ",";
          query += ":ARG" + i;
        }
        query += ")";
        CostQuery[items] = new OracleCommand(query, objConn);
        for (int i = 0; i < items; i++)
        {
          CostQuery[items].Parameters.Add(":ARG" + i, OracleDbType.Int32);
        }
      }

      // Manager thread stored procedures
      Remove_Review_By_Product = new OracleCommand("DS3.RemoveReviewByProduct" + target_store_number, objConn);
      Remove_Review_By_Product.CommandType = CommandType.StoredProcedure;
      Remove_Review_By_Product.Parameters.Add("p_prod_id", OracleDbType.Int32);
      Remove_Review_By_Product.Parameters.Add("p_review_id", OracleDbType.Int32, ParameterDirection.Output);

      Remove_Unhelpful_Reviews = new OracleCommand("DS3.RemoveUnhelpfulReviews" + target_store_number, objConn);
      Remove_Unhelpful_Reviews.CommandType = CommandType.StoredProcedure;
      Remove_Unhelpful_Reviews.Parameters.Add("p_batch_size", OracleDbType.Int32);
      Remove_Unhelpful_Reviews.Parameters.Add("p_rows_affected", OracleDbType.Int32, ParameterDirection.Output);

      Adjust_Prices = new OracleCommand("DS3.AdjustPrices" + target_store_number, objConn);
      Adjust_Prices.CommandType = CommandType.StoredProcedure;
      Adjust_Prices.Parameters.Add("p_prod_id", OracleDbType.Int32);
      Adjust_Prices.Parameters.Add("p_rows_affected", OracleDbType.Int32, ParameterDirection.Output);

      Mark_Specials = new OracleCommand("DS3.MarkSpecials" + target_store_number, objConn);
      Mark_Specials.CommandType = CommandType.StoredProcedure;
      Mark_Specials.Parameters.Add("p_prod_id", OracleDbType.Int32);
      Mark_Specials.Parameters.Add("p_rows_affected", OracleDbType.Int32, ParameterDirection.Output);
    }

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2connect()
      {
      try
        {
        objConn.Open();
        //Console.WriteLine("Thread {0}: connected to database {1}",  Thread.CurrentThread.Name, Controller.target);
        //changed by GSK
        //Console.WriteLine("Thread {0}: connected to database {1}", Thread.CurrentThread.Name, target_server_name);
        }
      catch (OracleException e)
        {
        //Console.WriteLine("Thread {0}: Oracle error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
        //  Controller.target, e.Message);
        //Changed by GSK
        Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}", Thread.CurrentThread.Name,
        target_server_name, e.Message);
        return (false);
        }
      catch (System.Exception e)
        {
        //Console.WriteLine("Thread {0}: System error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
        //  Controller.target, e.Message);
        //return(false);
        //Changed by GSK
        Console.WriteLine("Thread {0}: System error in connecting to database {1}: {2}", Thread.CurrentThread.Name,
        target_server_name, e.Message);
        return (false);
        }

      return(true);
      } // end ds2connect()

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2login(string username_in, string password_in, ref int customerid_out, ref int rows_returned,
      ref string[] title_out, ref string[] actor_out, ref string[] related_title_out, ref double rt)
      {
      Login.Parameters["p_username_in"].Value = username_in;
      Login.Parameters["p_password_in"].Value = password_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        using (OracleDataReader Rdr = Login.ExecuteReader())
        {
          customerid_out = Convert.ToInt32(Login.Parameters["p_customerid"].Value.ToString());
          int i_row = 0;

          while (Rdr.Read() && (i_row < GlobalConstants.MAX_ROWS))
          {
             title_out[i_row] = Rdr.GetString(0);
             actor_out[i_row] = Rdr.GetString(1);
             related_title_out[i_row] = Rdr.GetString(2);
             // Console.WriteLine("  title= {0}  actor= {1}  related_title= {2}", title_out[i_row], actor_out[i_row], related_title_out[i_row]);
             i_row++;
          }
          rows_returned = i_row;
        }
        return(true);
        }
      catch (OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in Login: {1}", Thread.CurrentThread.Name, e.Message);
        return (false);
        }
      catch (Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in Login: {1}", Thread.CurrentThread.Name, e.Message);
        return (false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }

      // Console.WriteLine("Thread {0}: {1} successfully logged in;   rows_returned={2}  customerid_out={3}", Thread.CurrentThread.Name, username_in, rows_returned, customerid_out);

      }  // end ds2login
//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2newcustomer(string username_in, string password_in, string firstname_in,
      string lastname_in, string address1_in, string address2_in, string city_in, string state_in,
      string zip_in, string country_in, string email_in, string phone_in, int creditcardtype_in,
      string creditcard_in, int ccexpmon_in, int ccexpyr_in, int age_in, int income_in,
      string gender_in, ref int customerid_out, ref double rt)
      {
      int region_in = (country_in == "US") ? 1:2;
      string creditcardexpiration_in = String.Format("{0:D4}/{1:D2}", ccexpyr_in, ccexpmon_in);

      New_Customer_prm[0].Value = firstname_in;
      New_Customer_prm[1].Value = lastname_in;
      New_Customer_prm[2].Value = address1_in;
      New_Customer_prm[3].Value = address2_in;
      New_Customer_prm[4].Value = city_in;
      New_Customer_prm[5].Value = state_in;
      New_Customer_prm[6].Value = (zip_in=="") ? 0 : Convert.ToInt32(zip_in);
      New_Customer_prm[7].Value = country_in;
      New_Customer_prm[8].Value = region_in;
      New_Customer_prm[9].Value = email_in;
      New_Customer_prm[10].Value = phone_in;
      New_Customer_prm[11].Value = creditcardtype_in;
      New_Customer_prm[12].Value = creditcard_in;
      New_Customer_prm[13].Value = creditcardexpiration_in;
      New_Customer_prm[14].Value = username_in;
      New_Customer_prm[15].Value = password_in;
      New_Customer_prm[16].Value = age_in;
      New_Customer_prm[17].Value = income_in;
      New_Customer_prm[18].Value = gender_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        New_Customer.ExecuteNonQuery();
        customerid_out = Convert.ToInt32(New_Customer_prm[19].Value.ToString());
        return(true);
        }
      catch (OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in New_Customer.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      catch (System.Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in New_Customer.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }

//    Console.WriteLine("Thread {0}: New_Customer created w/username_in= {1}  region={2}  customerid={3}",
//      Thread.CurrentThread.Name, username_in, region_in, customerid_out);

      } // end ds2newcustomer()

//
//-------------------------------------------------------------------------------------------------
//
      public bool ds2newmember(int customerid_in, int membershiplevel_in, ref int customerid_out, ref double rt)
      {
      New_Member_prm[0].Value = customerid_in;
      New_Member_prm[1].Value = membershiplevel_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        New_Member.ExecuteNonQuery();
        customerid_out = Convert.ToInt32(New_Member_prm[2].Value.ToString());
        return(true);
        }
      catch (OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in New_Member.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      catch (System.Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in New_Member.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }

//    Console.WriteLine("Thread {0}: New_Customer created w/username_in= {1}  region={2}  customerid={3}",
//      Thread.CurrentThread.Name, username_in, region_in, customerid_out);

      } // end ds2newmember()


//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2browse(string browse_type_in, string browse_category_in, string browse_actor_in,
      string browse_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref decimal[] price_out,
      ref int[] special_out, ref int[] common_prod_id_out, ref double rt)
      {
      // Products table: PROD_ID INT, CATEGORY TINYINT, TITLE VARCHAR(50), ACTOR VARCHAR(50),
      //   PRICE DECIMAL(12,2), SPECIAL TINYINT, COMMON_PROD_ID INT
      int membership_item = 0;
      int special = 0;
      string data_in = string.Empty;
      int[] category_out = new int[GlobalConstants.MAX_ROWS];

      // Search for special half the time
      if (Random.Shared.Next(100) < 50) {
        special = 1;
      }

      switch(browse_type_in)
        {
        case "category":
          Browse_By_Category.Parameters["p_category_in"].Value = Convert.ToInt32(browse_category_in);
          Browse_By_Category.Parameters["p_batch_size"].Value = batch_size_in;
          Browse_By_Category.Parameters["p_special_in"].Value = special;
          data_in = browse_category_in;
          break;
        case "actor":
          Browse_By_Actor.Parameters["p_actor_in"].Value = browse_actor_in.Split(' ')[0];;
          Browse_By_Actor.Parameters["p_batch_size"].Value = batch_size_in;
	  data_in = "\"" + browse_actor_in + "\"";
          break;
        case "title":
          Browse_By_Title.Parameters["p_title_in"].Value = browse_title_in.Split(' ')[0];
          Browse_By_Title.Parameters["p_batch_size"].Value = batch_size_in;
	  data_in = "\"" + browse_title_in + "\"";
          break;
        case "membership":
          Browse_By_Membership.Parameters["p_batch_size"].Value = batch_size_in;
          Browse_By_Membership.Parameters["p_membershiptype_in"].Value = Random.Shared.Next(1, 4);
	  data_in = "membership level: " + Browse_By_Membership.Parameters["p_membershiptype_in"].Value;
          break;
        default:
          Console.WriteLine("  Browse type '{0}' unsupported.",browse_type_in);
          rows_returned = -1;
          return false;
        }

      //Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1} batch_size_in= {2} data_in= {3}",
      //Thread.CurrentThread.Name, browse_type_in, batch_size_in, data_in );

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        OracleDataReader Rdr;
        switch(browse_type_in)
          {
          default:
          case "category":
            Rdr = Browse_By_Category.ExecuteReader();
            break;
          case "actor":
            Rdr = Browse_By_Actor.ExecuteReader();
            break;
          case "title":
            Rdr = Browse_By_Title.ExecuteReader();
            break;
          case "membership":
            Rdr = Browse_By_Membership.ExecuteReader();
            break;
          }

        using (Rdr)
        {
          int i_row = 0;
          while (Rdr.Read())
          {
            prod_id_out[i_row] = Rdr.GetInt32(0);
            category_out[i_row] = Rdr.GetByte(1);
            title_out[i_row] = Rdr.GetString(2);
            actor_out[i_row] = Rdr.GetString(3);
            price_out[i_row] = Rdr.GetDecimal(4);
            special_out[i_row] = Rdr.GetByte(5);
            common_prod_id_out[i_row] = Rdr.GetInt32(6);
	    membership_item = Rdr.GetInt32(7);
            //Console.WriteLine("\tprod_id_out: {0} category_out: {1} title_out: {2} actor_out: {3} price_out: {4} special_out: {5} common_prod_id_out: {6} membership_item: {7}",prod_id_out[i_row],category_out[i_row],title_out[i_row],actor_out[i_row],price_out[i_row], special_out[i_row],common_prod_id_out[i_row], membership_item);
            ++i_row;
          }
          rows_returned = i_row;
        }
        return(true);
        }
      catch (OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in Browse: {1}", Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      catch (System.Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in Browse: {1}", Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }
      } // end ds2browse()

//
//-------------------------------------------------------------------------------------------------
//

    public bool ds2browsereview(string browse_review_type_in, string get_review_category_in, string get_review_actor_in,
      string get_review_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref int[] review_id_out,
      ref string[] review_date_out, ref int[] review_stars_out,ref int[] review_customerid_out,
      ref string[]review_summary_out, ref string[]review_text_out, ref int[]review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)

        switch (browse_review_type_in)
        {
            default:
            case "actor":
                Get_Prod_Reviews_By_Actor.Parameters["p_actor_in"].Value = get_review_actor_in;
                Get_Prod_Reviews_By_Actor.Parameters["p_batch_size"].Value = batch_size_in;
                Get_Prod_Reviews_By_Actor.Parameters["p_search_depth"].Value = search_depth_in;
                break;
            case "title":
                Get_Prod_Reviews_By_Title.Parameters["p_title_in"].Value = get_review_title_in;
                Get_Prod_Reviews_By_Title.Parameters["p_batch_size"].Value = batch_size_in;
                Get_Prod_Reviews_By_Title.Parameters["p_search_depth"].Value = search_depth_in;
                break;
        }

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            OracleDataReader Rdr;
            switch (browse_review_type_in)
            {
               case "actor":
                  Rdr = Get_Prod_Reviews_By_Actor.ExecuteReader();
                  break;
               case "title":
               default:
                  Rdr = Get_Prod_Reviews_By_Title.ExecuteReader();
                  break;
            }

            using (Rdr)
            {
              int i_row = 0;
              while (Rdr.Read())
              {
                  title_out[i_row] = Rdr.GetString(0);
                  actor_out[i_row] = Rdr.GetString(1);
                  review_id_out[i_row] = Rdr.GetInt32(2);
                  prod_id_out[i_row] = Rdr.GetInt32(3);
                  review_date_out[i_row] = Rdr.GetDateTime(4).ToString();
                  review_stars_out[i_row] = Rdr.GetInt32(5);
                  review_customerid_out[i_row] = Rdr.GetInt32(6);
                  review_summary_out[i_row] = Rdr.GetString(7);
                  review_text_out[i_row] = Rdr.GetString(8);
                  review_helpfulness_sum_out[i_row] = Rdr.GetInt32(9);
                  //Console.WriteLine("\tprod_id_out: {0} title_out: {1} actor_out: {2} review_id_out: {3} review_date_out: {4} review_stars_out: {5} review_customerid_out: {6} review_summary_out: {7}\n\treview_text_out: {8} review_helpfulness_sum_out: {9}\n", prod_id_out[i_row], title_out[i_row], actor_out[i_row], review_id_out[i_row], review_date_out[i_row], review_stars_out[i_row], review_customerid_out[i_row], review_summary_out[i_row], review_text_out[i_row], review_helpfulness_sum_out[i_row] );
                  ++i_row;
              } // end while rdr.read()
              rows_returned = i_row;
            }
            return (true);
        }
        catch (OracleException e)
        {
            Console.WriteLine("Thread {0}: Oracle Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }

        //    Console.WriteLine("Thread {0}: Browse successful: type= {1}  rows_returned={2}",
        //       Thread.CurrentThread.Name, browse_type_in, rows_returned);

    } // end ds2browsereview()

    //
    //-------------------------------------------------------------------------------------------------
    //

    public bool ds2getreview(string get_review_type_in, int get_review_prod_in, int get_review_stars_in, int customerid_out, int batch_size_in, ref int rows_returned,
      ref int[] prod_id_out, ref int[] review_id_out, ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)

        switch (get_review_type_in)
        {
            case "noorder":
            default:
                Get_Prod_Reviews.Parameters["p_batch_size"].Value = batch_size_in;
                Get_Prod_Reviews.Parameters["p_prod_in"].Value = get_review_prod_in;
                break;
            case "star":
                Get_Prod_Reviews_By_Stars.Parameters["p_batch_size"].Value = batch_size_in;
                Get_Prod_Reviews_By_Stars.Parameters["p_prod_in"].Value = get_review_prod_in;
                Get_Prod_Reviews_By_Stars.Parameters["p_stars_in"].Value = get_review_stars_in;
                break;
            case "date":
                Get_Prod_Reviews_By_Date.Parameters["p_batch_size"].Value = batch_size_in;
                Get_Prod_Reviews_By_Date.Parameters["p_prod_in"].Value = get_review_prod_in;
                break;
        }

        //Console.WriteLine("Thread {0}: Calling Get Review w/ review_type= {1}  batch_size_in= {2}  get_review_prod_in= {3}", Thread.CurrentThread.Name, get_review_type_in, batch_size_in, get_review_prod_in);

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            OracleDataReader Rdr;
            switch (get_review_type_in)
            {
                case "noorder":
                default:
                   Rdr = Get_Prod_Reviews.ExecuteReader();
                   break;
                case "star":
                   Rdr = Get_Prod_Reviews_By_Stars.ExecuteReader();
                   break;
                case "date":
                   Rdr = Get_Prod_Reviews_By_Date.ExecuteReader();
                   break;
            }

            using (Rdr)
            {
              int i_row = 0;
              while (Rdr.Read())
              {
                  review_id_out[i_row] = Rdr.GetInt32(0);
                  prod_id_out[i_row] = Rdr.GetInt32(1);
                  review_date_out[i_row] = Rdr.GetDateTime(2).ToString();
                  review_stars_out[i_row] = Rdr.GetInt32(3);
                  review_customerid_out[i_row] = Rdr.GetInt32(4);
                  review_summary_out[i_row] = Rdr.GetString(5);
                  review_text_out[i_row] = Rdr.GetString(6);
                  review_helpfulness_sum_out[i_row] = Rdr.GetInt32(7);
                  //Console.WriteLine("\treview_id_out: {0} prod_id_out: {1} review_date_out: {2} review_stars_out: {3} review_customerid_out: {4} review_summary_out: {5} review_text_out: {6} review_helpfulness_sum_out: {7}",
                  //  review_id_out[i_row], prod_id_out[i_row], review_date_out[i_row], review_stars_out[i_row], review_customerid_out[i_row], review_summary_out[i_row], review_text_out[i_row], review_helpfulness_sum_out[i_row]);
                  ++i_row;
              }
              rows_returned = i_row;
            }
            return (true);
        }
        catch (OracleException e)
        {
            Console.WriteLine("Thread {0}: Oracle Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }

        //    Console.WriteLine("Thread {0}: Browse successful: type= {1}  rows_returned={2}",
        //       Thread.CurrentThread.Name, get_review_type_in, rows_returned);

    } // end ds2getreview()

    //
    //-------------------------------------------------------------------------------------------------
    //
      public bool ds2newreview(int new_review_prod_id_in, int new_review_stars_in, int new_review_customerid_in,
              string new_review_summary_in, string new_review_text_in, ref int newreviewid_out, ref double rt)
    {
      New_Prod_Review_prm[0].Value = new_review_prod_id_in;
      New_Prod_Review_prm[1].Value = new_review_stars_in;
      New_Prod_Review_prm[2].Value = new_review_customerid_in;
      New_Prod_Review_prm[3].Value = new_review_summary_in;
      New_Prod_Review_prm[4].Value = new_review_text_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        New_Prod_Review.ExecuteNonQuery();
        newreviewid_out = Convert.ToInt32(New_Prod_Review_prm[5].Value.ToString());
        return(true);
        }
      catch (OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in New_Prod_Review.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      catch (System.Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in New_Prod_Review.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }
      } // end ds2newreview()



    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2newreviewhelpfulness(int reviewid_in, int customerid_in, int reviewhelpfulness_in, ref int reviewhelpfulnessid_out, ref double rt)
    {
        New_Review_Helpfulness_prm[0].Value = reviewid_in;
        New_Review_Helpfulness_prm[1].Value = customerid_in;
        New_Review_Helpfulness_prm[2].Value = reviewhelpfulness_in;

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            New_Review_Helpfulness.ExecuteNonQuery();
            reviewhelpfulnessid_out = Convert.ToInt32(New_Review_Helpfulness_prm[3].Value.ToString());
            return (true);
        }
        catch (OracleException e)
        {
            Console.WriteLine("Thread {0}: Oracle Error in New_Review_Helpfulness.ExecuteNonQuery(): {1}",
              Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in New_Review_Helpfulness.ExecuteNonQuery(): {1}",
              Thread.CurrentThread.Name, e.Message);
            return (false);
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }
    } // end ds2newreviewhelpfulness()


    public bool ds2purchase(int cart_items, int[] prod_id_in, int[] qty_in, int customerid_out,
      ref int neworderid_out, ref bool IsRollback, ref double rt)
      {
      int i, j;

      //Cap cart_items at 10 for this implementation of stored procedure
      cart_items = System.Math.Min(10, cart_items);

      // Extra, non-stored procedure query to find total cost of purchase
      decimal netamount_in = 0;

      // Use pre-compiled cost query command
      var cost_command = CostQuery[cart_items];
      for (i = 0; i < cart_items; i++)
      {
        cost_command.Parameters[":ARG" + i].Value = prod_id_in[i];
      }

      using (OracleDataReader Rdr = cost_command.ExecuteReader())
      {
        while (Rdr.Read())
        {
          j = 0;
          int prod_id = Convert.ToInt32(Rdr.GetDecimal(0));
          while (prod_id_in[j] != prod_id) ++j; // Find which product was returned
          netamount_in = netamount_in + qty_in[j] * Rdr.GetDecimal(1);
          //Console.WriteLine(j + " " + prod_id + " " + qty_in[j] + " " + Rdr.GetDecimal(1));
        }
      }

      // Can use following code instead if you don't want extra roundtrip to database:
      //Random rr = new Random(DateTime.Now.Millisecond);
      //decimal netamount_in = (decimal) (0.01 * (1 + rr.Next(40000)));
      //Console.WriteLine(netamount_in);
      decimal taxamount_in =  (decimal) 0.0825 * netamount_in;
      decimal totalamount_in = netamount_in + taxamount_in;

      Purchase_prm[0].Value = customerid_out;
      Purchase_prm[1].Value = cart_items;
      Purchase_prm[2].Value = netamount_in;
      Purchase_prm[3].Value = taxamount_in;
      Purchase_prm[4].Value = totalamount_in;

      Purchase_prod_id_in.Value = prod_id_in;
      Purchase_qty_in.Value = qty_in;

    //Console.WriteLine("Thread {0}: Calling Purchase w/ customerid = {1}  number_items= {2}", Thread.CurrentThread.Name, customerid_out, cart_items);

      Stopwatch timer = Stopwatch.StartNew();

      try
        {
        Purchase.ExecuteNonQuery();
        neworderid_out = Convert.ToInt32(Purchase_prm[5].Value.ToString());
        if (neworderid_out == 0) IsRollback = true;
        return(true);
        }
      catch(OracleException e)
        {
        Console.WriteLine("Thread {0}: Oracle Error in Purchase.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      catch(System.Exception e)
        {
        Console.WriteLine("Thread {0}: System Error in Purchase.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return(false);
        }
      finally
        {
        rt = timer.Elapsed.TotalSeconds;
        }

//    Console.WriteLine("Thread {0}: Purchase successful: customerid = {1}  number_items= {2}  IsRollback= {3}",
//      Thread.CurrentThread.Name, customerid_out, cart_items, IsRollback);

      } // end ds2purchase()

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2newproduct(int new_category_in, string new_title_in, string new_actor_in, decimal new_price_in, int new_stock_in, ref int newproduct_id, ref double rt)
    {
      New_Product.Parameters["p_cat"].Value = new_category_in;
      New_Product.Parameters["p_title"].Value = new_title_in;
      New_Product.Parameters["p_actor"].Value = new_actor_in;
      New_Product.Parameters["p_price"].Value = new_price_in;
      New_Product.Parameters["p_stock"].Value = new_stock_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
          New_Product.ExecuteNonQuery();
          newproduct_id = Convert.ToInt32(New_Product.Parameters["p_gen_id"].Value.ToString());
          return (true);
      }
      catch (OracleException e)
      {
          Console.WriteLine("Thread {0}: Oracle Error {1} in New_Product: {2}",Thread.CurrentThread.Name, e.Number, e.Message);
          return (false);
      }
      catch (System.Exception e)
      {
          Console.WriteLine("Thread {0}: System Error in New_Product: {1}", Thread.CurrentThread.Name, e.Message);
          return (false);
      }
      finally
      {
          rt = timer.Elapsed.TotalSeconds;
      }
    }


//
//-------------------------------------------------------------------------------------------------
// Manager Thread Methods
//-------------------------------------------------------------------------------------------------
//
    public int ds36removereviewbyproduct(int prodId, ref double rt)
    {
        Remove_Review_By_Product.Parameters["p_prod_id"].Value = prodId;

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            Remove_Review_By_Product.ExecuteNonQuery();
            return Convert.ToInt32(Remove_Review_By_Product.Parameters["p_review_id"].Value.ToString());
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36removereviewbyproduct error: {e.Message}");
            return 0;
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int ds36removeunhelpfulreviews(int batchSize, ref double rt)
    {
        Remove_Unhelpful_Reviews.Parameters["p_batch_size"].Value = batchSize;

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            Remove_Unhelpful_Reviews.ExecuteNonQuery();
            object result = Remove_Unhelpful_Reviews.Parameters["p_rows_affected"].Value;
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36removeunhelpfulreviews error: {e.Message}");
            return 0;
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int ds36adjustprices(int prodId, ref double rt)
    {
        Adjust_Prices.Parameters["p_prod_id"].Value = prodId;

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            Adjust_Prices.ExecuteNonQuery();
            object result = Adjust_Prices.Parameters["p_rows_affected"].Value;
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36adjustprices error: {e.Message}");
            return 0;
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int ds36markspecials(int prodId, ref double rt)
    {
        Mark_Specials.Parameters["p_prod_id"].Value = prodId;

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            Mark_Specials.ExecuteNonQuery();
            object result = Mark_Specials.Parameters["p_rows_affected"].Value;
            return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36markspecials error: {e.Message}");
            return 0;
        }
        finally
        {
            rt = timer.Elapsed.TotalSeconds;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2close()
      {
      objConn.Close();
      return(true);
      } // end ds2close()
    } // end Class ds2Interface
  } // end namespace ds2xdriver

